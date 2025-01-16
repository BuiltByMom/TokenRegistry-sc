// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/TokenRegistry.sol";
import "../src/TokentrollerV1.sol";

contract UploadTokensBatchScript is Script {
    struct Token {
        address address_;
        string name;
        string symbol;
        string logoURI;
        uint8 decimals;
    }

    function run(uint256 startIndex, uint256 batchSize) public {
        require(batchSize > 0, "Batch size must be greater than 0");
        vm.txGasPrice(0);

        console.log("Processing batch starting at index %d with size %d", startIndex, batchSize);

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/tokens.json");
        string memory json = vm.readFile(path);

        // Count total tokens first
        uint256 tokenCount;
        bool countingComplete;
        while (!countingComplete && tokenCount < 1000) {
            try this.parseToken(json, tokenCount) returns (Token memory) {
                tokenCount++;
            } catch {
                countingComplete = true;
            }
        }

        require(startIndex < tokenCount, "Start index out of bounds");
        console.log("Found %d total tokens", tokenCount);

        // Calculate actual batch size
        uint256 remainingTokens = tokenCount - startIndex;
        uint256 actualBatchSize = batchSize > remainingTokens ? remainingTokens : batchSize;

        address tokenRegistryAddress = vm.envAddress("TOKEN_REGISTRY_ADDRESS");
        address owner = vm.envAddress("INITIAL_OWNER");
        TokenRegistry registry = TokenRegistry(tokenRegistryAddress);

        console.log("Registry address:", tokenRegistryAddress);
        console.log("Owner address:", owner);
        console.log("Processing tokens %d to %d", startIndex, startIndex + actualBatchSize - 1);

        vm.startBroadcast(owner);

        uint256 successCount = 0;
        uint256 approvedCount = 0;
        // Process batch
        for (uint256 i = startIndex; i < startIndex + actualBatchSize; i++) {
            try this.parseToken(json, i) returns (Token memory token) {
                try registry.addToken(token.address_, token.name, token.symbol, token.logoURI, token.decimals) {
                    successCount++;
                    console.log("Added token: %s (%s)", token.name, token.symbol);

                    // Approve every third token
                    if (i % 3 == 0) {
                        try registry.approveToken(token.address_) {
                            approvedCount++;
                            console.log("Approved token: %s", token.symbol);
                        } catch Error(string memory reason) {
                            console.log("Failed to approve token %s: %s", token.symbol, reason);
                        }
                    }
                } catch Error(string memory reason) {
                    console.log("Failed to add token %s: %s", token.symbol, reason);
                }
            } catch {
                console.log("Failed to parse token at index %d", i);
            }
        }

        vm.stopBroadcast();

        console.log(
            "Batch complete. Added %d/%d tokens, approved %d tokens",
            successCount,
            actualBatchSize,
            approvedCount
        );

        // Log progress
        if (startIndex + actualBatchSize < tokenCount) {
            console.log("To process next batch, run with --start-index %d", startIndex + actualBatchSize);
        } else {
            console.log("All tokens processed!");
        }
    }

    function parseToken(string memory json, uint256 index) external view returns (Token memory) {
        string memory prefix = string.concat(".tokens[", vm.toString(index), "]");
        return
            Token({
                address_: vm.parseJsonAddress(json, string.concat(prefix, ".address_")),
                name: vm.parseJsonString(json, string.concat(prefix, ".name")),
                symbol: vm.parseJsonString(json, string.concat(prefix, ".symbol")),
                logoURI: vm.parseJsonString(json, string.concat(prefix, ".logoURI")),
                decimals: uint8(vm.parseJsonUint(json, string.concat(prefix, ".decimals")))
            });
    }
}
