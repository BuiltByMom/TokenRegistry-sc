// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/TokenRegistry.sol";
import "src/TokenEdits.sol";
import "src/controllers/TokentrollerV1.sol";
import "src/interfaces/ISharedTypes.sol";

contract CreateEditsScript is Script {
    // Number of edits to create per token
    uint256 constant EDITS_PER_TOKEN = 2;
    // Maximum number of tokens to create edits for
    uint256 constant MAX_TOKENS = 5;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Get contract addresses from environment
        address tokentrollerAddress = vm.envAddress("TOKENTROLLER_ADDRESS");
        address tokenRegistryAddress = TokentrollerV1(tokentrollerAddress).tokenRegistry();
        address tokenEditsAddress = TokentrollerV1(tokentrollerAddress).tokenEdits();

        ITokenEdits tokenEdits = ITokenEdits(tokenEditsAddress);
        ITokenRegistry registry = ITokenRegistry(tokenRegistryAddress);

        // Get approved tokens
        (ITokenRegistry.Token[] memory tokens, uint256 total) = registry.listTokens(
            0,
            MAX_TOKENS,
            TokenStatus.APPROVED
        );
        console.log("Found %d approved tokens (limited to %d)", total, MAX_TOKENS);

        // Create edits for each token
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddress = tokens[i].contractAddress;
            console.log("Creating edits for token %d: %s (%s)", i + 1, tokens[i].name, vm.toString(tokenAddress));

            // Create multiple edits per token
            for (uint256 j = 0; j < EDITS_PER_TOKEN; j++) {
                MetadataInput[] memory metadata = generateRandomEdit(j);

                try tokenEdits.proposeEdit(tokenAddress, metadata) {
                    console.log("  Created edit %d", j + 1);
                } catch Error(string memory reason) {
                    console.log("  Failed to create edit %d: %s", j + 1, reason);
                }
            }
        }

        vm.stopBroadcast();
    }

    function generateRandomEdit(uint256 seed) internal view returns (MetadataInput[] memory) {
        // Create an array with one metadata update
        MetadataInput[] memory metadata = new MetadataInput[](1);

        // Generate a random logoURI based on the seed
        string memory logoURI = string(
            abi.encodePacked(
                "https://example.com/token-logo-",
                vm.toString(seed),
                "-",
                vm.toString(block.timestamp),
                ".png"
            )
        );

        metadata[0] = MetadataInput({ field: "logoURI", value: logoURI });

        return metadata;
    }
}
