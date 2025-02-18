import {
  createPublicClient,
  createWalletClient,
  http,
  Address,
  parseAbi,
  Hex,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import axios from "axios";
import * as dotenv from "dotenv";
import { createHash } from "crypto";
import { abi as helperAbi } from "../out/Helper.sol/Helper.json";
import { readFileSync, writeFileSync, existsSync } from "fs";
import { resolve } from "path";

// Load environment variables
dotenv.config({ path: ".env.local" });

// Constants
const BATCH_SIZE = 20;
const CONCURRENT_UPLOADS = 5; // Number of concurrent image uploads
const CACHE_FILE = ".pinata-cache.json";
const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36";
const SMOLDAPP_TOKEN_LIST_URL =
  "https://raw.githubusercontent.com/SmolDapp/tokenLists/main/lists";

// Environment variables
const { HELPER_ADDRESS, PINATA_JWT, PINATA_GROUP, RPC_URL, PRIVATE_KEY } =
  process.env;

if (!HELPER_ADDRESS || !PINATA_JWT || !RPC_URL || !PRIVATE_KEY) {
  throw new Error("Required environment variables not set");
}

// Setup viem clients
const publicClient = createPublicClient({
  transport: http(RPC_URL),
});

const account = privateKeyToAccount(PRIVATE_KEY as Hex);
const walletClient = createWalletClient({
  account,
  transport: http(RPC_URL),
});

// Types
interface Token {
  address: string;
  name: string;
  symbol: string;
  logoURI: string;
  chainId: number;
  decimals: number;
}

interface TokenList {
  tokens: Token[];
}

interface PinataCache {
  [key: string]: {
    ipfsHash: string;
    timestamp: number;
    logoUrl: string;
  };
}

// Load or initialize cache
let pinataCache: PinataCache = {};
if (existsSync(CACHE_FILE)) {
  try {
    pinataCache = JSON.parse(readFileSync(CACHE_FILE, "utf-8"));
    console.log(`Loaded ${Object.keys(pinataCache).length} cached IPFS hashes`);
  } catch (error) {
    console.warn("Failed to load cache, starting fresh");
  }
}

// Save cache
function saveCache() {
  try {
    writeFileSync(CACHE_FILE, JSON.stringify(pinataCache, null, 2));
  } catch (error) {
    console.warn("Failed to save cache");
  }
}

// Generate cache key for a token
function getCacheKey(address: string, logoUrl: string): string {
  return createHash("sha256")
    .update(`${address}-${logoUrl}`)
    .digest("hex")
    .slice(0, 16);
}

async function checkPinataFile(ipfsHash: string): Promise<boolean> {
  try {
    const response = await axios.get(
      `https://gateway.pinata.cloud/ipfs/${ipfsHash}`,
      {
        timeout: 5000, // 5 second timeout
      }
    );
    return response.status === 200;
  } catch {
    return false;
  }
}

async function downloadAndPinImage(
  imageUrl: string,
  address: string,
  retryCount = 0
): Promise<string> {
  const maxRetries = 3;
  const cacheKey = getCacheKey(address, imageUrl);

  // Check cache first
  if (pinataCache[cacheKey]) {
    const cached = pinataCache[cacheKey];
    // Verify the cached file still exists
    if (await checkPinataFile(cached.ipfsHash)) {
      console.log(`Using cached IPFS hash for ${address}: ${cached.ipfsHash}`);
      return cached.ipfsHash;
    } else {
      console.log(`Cached file not found, re-uploading for ${address}`);
      delete pinataCache[cacheKey];
    }
  }

  try {
    // Download image
    const response = await axios.get(imageUrl, {
      responseType: "arraybuffer",
      headers: {
        "User-Agent": USER_AGENT,
      },
      timeout: 10000, // 10 second timeout
    });

    // Validate content type
    const contentType = response.headers["content-type"];
    if (!contentType?.startsWith("image/") && contentType !== "image/svg+xml") {
      throw new Error(`Invalid content type: ${contentType}`);
    }

    // Generate hash
    const chainId = await publicClient.getChainId();
    const fileSize = response.data.length;
    const lastModified = Date.now();
    const hash = createHash("sha256")
      .update(`${chainId}-${address}-${fileSize}-${lastModified}`)
      .digest("hex")
      .slice(0, 8);

    // Prepare pinata upload
    const formData = new FormData();
    const blob = new Blob([response.data], { type: contentType });
    formData.append("file", blob);

    // Add metadata if PINATA_GROUP is set
    if (PINATA_GROUP) {
      const metadata = {
        name: `${chainId}-${address}-${hash}`,
        keyvalues: {
          source: "token_registry_script",
          chain: chainId.toString(),
          address,
          originalUrl: imageUrl,
        },
      };
      formData.append("pinataMetadata", JSON.stringify(metadata));
      formData.append(
        "pinataOptions",
        JSON.stringify({ groupId: PINATA_GROUP })
      );
    }

    // Upload to Pinata
    const pinataResponse = await axios.post(
      "https://api.pinata.cloud/pinning/pinFileToIPFS",
      formData,
      {
        headers: {
          Authorization: `Bearer ${PINATA_JWT}`,
          "Content-Type": "multipart/form-data",
        },
        timeout: 30000, // 30 second timeout
      }
    );

    if (!pinataResponse.data.IpfsHash) {
      throw new Error("Failed to get IPFS hash from Pinata response");
    }

    // Cache the result
    pinataCache[cacheKey] = {
      ipfsHash: pinataResponse.data.IpfsHash,
      timestamp: Date.now(),
      logoUrl: imageUrl,
    };
    saveCache();

    return pinataResponse.data.IpfsHash;
  } catch (error) {
    if (retryCount < maxRetries) {
      console.log(
        `Retrying upload for ${address} (attempt ${
          retryCount + 1
        }/${maxRetries})`
      );
      await new Promise((resolve) =>
        setTimeout(resolve, 2000 * (retryCount + 1))
      );
      return downloadAndPinImage(imageUrl, address, retryCount + 1);
    }
    if (error instanceof Error) {
      throw new Error(`Failed to process image: ${error.message}`);
    }
    throw error;
  }
}

async function processTokenBatch(tokens: Token[]): Promise<
  {
    contractAddress: Address;
    metadata: { field: string; value: string }[];
  }[]
> {
  // Process images in parallel with concurrency limit
  const results = [];
  for (let i = 0; i < tokens.length; i += CONCURRENT_UPLOADS) {
    const batch = tokens.slice(i, i + CONCURRENT_UPLOADS);
    const promises = batch.map(async (token) => {
      if (!token.logoURI) {
        console.warn(
          `Warning: No logoURI for token ${token.name} ${token.address}`
        );
        return null;
      }

      try {
        console.log(`Processing token ${token.name} (${token.symbol})...`);
        console.log(`Logo URL: ${token.logoURI}`);
        console.log(`Address: ${token.address}`);

        const ipfsHash = await downloadAndPinImage(
          token.logoURI,
          token.address
        );
        console.log(`IPFS Hash for ${token.name}: ${ipfsHash}`);

        return {
          contractAddress: token.address as Address,
          metadata: [
            {
              field: "logoURI",
              value: `ipfs://${ipfsHash}`,
            },
          ],
        };
      } catch (error) {
        console.warn(`Warning: Failed to process token ${token.name}:`, error);
        return null;
      }
    });

    const batchResults = await Promise.all(promises);
    results.push(
      ...batchResults.filter((r): r is NonNullable<typeof r> => r !== null)
    );
  }

  return results;
}

async function processBatch(tokens: Token[]) {
  const batchInput = await processTokenBatch(tokens);

  if (batchInput.length === 0) {
    console.log("No tokens to process in this batch");
    return;
  }

  try {
    // Simulate transaction first
    const { request } = await publicClient.simulateContract({
      address: HELPER_ADDRESS as Address,
      abi: helperAbi,
      functionName: "batchAddAndApproveTokens",
      args: [batchInput],
    });

    // Send transaction
    const hash = await walletClient.writeContract(request);
    console.log("Transaction submitted:", hash);

    // Wait for transaction
    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    if (receipt.status === "success") {
      console.log("Transaction successful!");
    } else {
      console.error("Transaction failed!");
    }
  } catch (error) {
    console.error("Failed to process batch:", error);
  }
}

async function loadTokenList(source: string): Promise<Token[]> {
  let tokenList: TokenList;

  try {
    // Check if source is a URL
    if (source.startsWith("http://") || source.startsWith("https://")) {
      console.log("Loading token list from URL:", source);
      const response = await axios.get<TokenList>(source);
      tokenList = response.data;
    } else {
      // Treat as local file path
      console.log("Loading token list from file:", source);
      const absolutePath = resolve(process.cwd(), source);
      const fileContent = readFileSync(absolutePath, "utf-8");
      tokenList = JSON.parse(fileContent);
    }

    // Validate token list format
    if (!tokenList || !Array.isArray(tokenList.tokens)) {
      throw new Error("Invalid token list format: missing tokens array");
    }

    // Get chain ID for validation
    const chainId = await publicClient.getChainId();

    // Filter and validate tokens
    const validTokens = tokenList.tokens.filter((token) => {
      // Basic validation
      const isValid =
        token.address &&
        token.name &&
        token.symbol &&
        token.decimals !== undefined &&
        token.chainId !== undefined;

      if (!isValid) {
        console.warn(
          `Skipping invalid token: ${token.address || "unknown address"}`
        );
        return false;
      }

      // Chain ID validation
      if (token.chainId !== chainId) {
        console.warn(
          `Skipping token ${token.address} - wrong chain ID (${token.chainId} vs ${chainId})`
        );
        return false;
      }

      return true;
    });

    console.log(
      `Loaded ${validTokens.length} valid tokens for chain ID ${chainId}`
    );
    return validTokens;
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Failed to load token list: ${error.message}`);
    }
    throw error;
  }
}

async function main() {
  try {
    // Get chain ID for SmolDapp URL
    const chainId = await publicClient.getChainId();

    // Get source from command line arguments or default to SmolDapp URL
    const source =
      process.argv[2] || `${SMOLDAPP_TOKEN_LIST_URL}/${chainId}.json`;

    // Load and validate tokens
    const tokens = await loadTokenList(source);
    console.log(`Found ${tokens.length} valid tokens to process`);

    // Process tokens in batches
    for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
      const batch = tokens.slice(i, i + BATCH_SIZE);
      console.log(`Processing batch ${i} to ${i + batch.length}...`);
      await processBatch(batch);

      // Wait between batches
      if (i + BATCH_SIZE < tokens.length) {
        console.log("Waiting before next batch...");
        await new Promise((resolve) => setTimeout(resolve, 2000));
      }
    }

    console.log("Processing complete!");
  } catch (error) {
    console.error("Script failed:", error);
    process.exit(1);
  }
}

main();
