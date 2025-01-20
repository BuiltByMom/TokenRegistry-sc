// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/TokenRegistry.sol";
import "src/TokentrollerV1.sol";
import "src/interfaces/ITokenRegistry.sol";

contract UploadTokensBatchScript is Script {
    struct Token {
        address address_;
        string logoURI;
        string name;
        string symbol;
    }

    function run(uint256 startIndex, uint256 batchSize) public {
        require(batchSize > 0, "Batch size must be greater than 0");

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/tokens.json");
        string memory json = vm.readFile(path);

        // Count tokens by trying to parse until we fail
        uint256 tokenCount;
        bool countingComplete;
        while (!countingComplete) {
            try this.parseToken(json, tokenCount) returns (Token memory) {
                tokenCount++;
            } catch {
                countingComplete = true;
                // Adjust tokenCount since the last attempt failed
                if (tokenCount > 0) tokenCount--;
            }
        }

        console.log("Found %d tokens to upload", tokenCount);

        address tokenRegistryAddress = vm.envAddress("TOKEN_REGISTRY_ADDRESS");
        address tokentrollerAddress = vm.envAddress("TOKENTROLLER_ADDRESS");
        address owner = vm.envAddress("INITIAL_OWNER");

        TokenRegistry registry = TokenRegistry(tokenRegistryAddress);
        TokentrollerV1 tokentroller = TokentrollerV1(tokentrollerAddress);

        uint256 remainingTokens = tokenCount - startIndex;
        uint256 actualBatchSize = batchSize > remainingTokens ? remainingTokens : batchSize;

        console.log("Registry address:", tokenRegistryAddress);
        console.log("Tokentroller address:", tokentrollerAddress);
        console.log("Owner address:", owner);
        console.log("Processing tokens %d to %d", startIndex, startIndex + actualBatchSize - 1);

        vm.startBroadcast();

        uint256 successCount = 0;
        uint256 approvedCount = 0;
        // Process batch
        for (uint256 i = startIndex; i < startIndex + actualBatchSize; i++) {
            try this.parseToken(json, i) returns (Token memory token) {
                MetadataInput[] memory metadata = new MetadataInput[](1);
                metadata[0] = MetadataInput({ field: "logoURI", value: token.logoURI });
                try registry.addToken(token.address_, metadata) {
                    successCount++;
                    // Approve every second token
                    if (i % 2 == 0) {
                        try registry.approveToken(token.address_) {
                            approvedCount++;
                            console.log("Approved token: %s", token.symbol);
                        } catch Error(string memory reason) {
                            console.log("Failed to approve token %s: %s", token.symbol, reason);
                        }
                    }

                    if (i % 10 == 0) {
                        console.log(
                            "Progress: %d/%d tokens processed. Last added: %s",
                            i + 1,
                            actualBatchSize,
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

        // ... existing completion logging code ...
    }

    function parseToken(string memory json, uint256 index) external view returns (Token memory) {
        string memory prefix = string.concat(".tokens[", vm.toString(index), "]");
        return
            Token({
                address_: vm.parseJsonAddress(json, string.concat(prefix, ".address")),
                logoURI: vm.parseJsonString(json, string.concat(prefix, ".logoURI")),
                name: vm.parseJsonString(json, string.concat(prefix, ".name")),
                symbol: vm.parseJsonString(json, string.concat(prefix, ".symbol"))
            });
    }
}
