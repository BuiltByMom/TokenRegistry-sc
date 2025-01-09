// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/TokenRegistry.sol";
import "../src/TokentrollerV1.sol";

contract UploadTokensScript is Script {
    struct Token {
        address address_;
        string name;
        string symbol;
        string logoURI;
        uint8 decimals;
        uint256 chainId;
    }

    function run() public {
        vm.txGasPrice(0);
        uint256 gasLimit = 3_000_000_000;

        console.log("Uploading tokens...");

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/tokens.json");
        string memory json = vm.readFile(path);

        // Count tokens by trying to parse until we fail
        uint256 tokenCount;
        bool countingComplete;
        while (!countingComplete && tokenCount < 1000) {
            try this.parseToken(json, tokenCount) returns (Token memory) {
                tokenCount++;
            } catch {
                countingComplete = true;
            }
        }

        console.log("Found %d tokens to upload", tokenCount);

        address tokenRegistryAddress = vm.envAddress("TOKEN_REGISTRY_ADDRESS");
        address tokentrollerAddress = vm.envAddress("TOKENTROLLER_ADDRESS");
        address owner = vm.envAddress("INITIAL_OWNER");

        TokenRegistry registry = TokenRegistry(tokenRegistryAddress);
        TokentrollerV1 tokentroller = TokentrollerV1(tokentrollerAddress);

        console.log("Registry address:", tokenRegistryAddress);
        console.log("Tokentroller address:", tokentrollerAddress);
        console.log("Owner address:", owner);

        vm.startBroadcast();

        uint256 successCount = 0;
        uint256 approvedCount = 0;
        // Process all tokens
        for (uint256 i = 0; i < tokenCount; i++) {
            try this.parseToken(json, i) returns (Token memory token) {
                try
                    registry.addToken{ gas: gasLimit }(
                        token.address_,
                        token.name,
                        token.symbol,
                        token.logoURI,
                        token.decimals,
                        token.chainId
                    )
                {
                    successCount++;
                    // Approve every third token
                    if (i % 3 == 0) {
                        try registry.approveToken(token.chainId, token.address_) {
                            approvedCount++;
                            console.log("Approved token: %s", token.symbol);
                        } catch Error(string memory reason) {
                            console.log("Failed to approve token %s: %s", token.symbol, reason);
                        }
                    }

                    if (i % 10 == 0) {
                        // Log progress every 10 tokens
                        console.log(
                            "Progress: %d/%d tokens processed. Last added: %s",
                            i + 1,
                            tokenCount,
                            token.symbol
                        );
                    }
                } catch Error(string memory reason) {
                    console.log("Failed to add token %s: %s", token.symbol, reason);
                }
            } catch {
                console.log("Failed to parse token at index %d", i);
            }
        }

        console.log(
            "Upload complete. Successfully added %d/%d tokens, approved %d tokens",
            successCount,
            tokenCount,
            approvedCount
        );
        vm.stopBroadcast();
    }

    function parseToken(string memory json, uint256 index) external view returns (Token memory) {
        string memory prefix = string.concat(".tokens[", vm.toString(index), "]");
        return
            Token({
                address_: vm.parseJsonAddress(json, string.concat(prefix, ".address_")),
                name: vm.parseJsonString(json, string.concat(prefix, ".name")),
                symbol: vm.parseJsonString(json, string.concat(prefix, ".symbol")),
                logoURI: vm.parseJsonString(json, string.concat(prefix, ".logoURI")),
                decimals: uint8(vm.parseJsonUint(json, string.concat(prefix, ".decimals"))),
                chainId: vm.parseJsonUint(json, string.concat(prefix, ".chainId"))
            });
    }
}
