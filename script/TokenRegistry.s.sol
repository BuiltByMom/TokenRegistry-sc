// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "src/TokenRegistry.sol";
import "src/TokentrollerV1.sol";
import "src/TokenMetadataRegistry.sol";

contract DeployTokenRegistry is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Set the initial owner address
        address initialOwner = vm.envAddress("INITIAL_OWNER");

        // Deploy the TokentrollerV1 contract
        TokentrollerV1 tokentroller = new TokentrollerV1(initialOwner);

        // The TokenRegistry and TokenMetadataRegistry are automatically deployed by the TokentrollerV1 constructor
        address tokenRegistryAddress = tokentroller.tokenRegistry();
        address metadataRegistryAddress = tokentroller.metadataRegistry();

        console.log("TokentrollerV1 deployed at:", address(tokentroller));
        console.log("TokenRegistry deployed at:", tokenRegistryAddress);
        console.log("TokenMetadataRegistry deployed at:", metadataRegistryAddress);

        vm.stopBroadcast();
    }
}
