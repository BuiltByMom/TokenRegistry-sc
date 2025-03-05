// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/controllers/HyperlaneRootPlugin.sol";
import { CreateXScript } from "./CreateXScript.sol";

contract DeployHyperlaneRootPlugin is Script, CreateXScript {
    address public hyperlaneRootPlugin;

    function run() external {
        // Load deployer key and addresses
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        address rootMailbox = vm.envAddress("HYPERLANE_ROOT_MAILBOX");

        address tokenMetadata = vm.envAddress("TOKEN_METADATA");
        address tokenRegistry = vm.envAddress("TOKEN_REGISTRY");
        address tokenEdits = vm.envAddress("TOKEN_EDITS");

        vm.startBroadcast(deployerPrivateKey);

        address deployer = msg.sender;

        bytes32 salt = bytes32(
            abi.encodePacked(
                deployer, // First 20 bytes - deployer address
                hex"00", // 21st byte - enable cross-chain protection
                bytes11(uint88(728980677978)) // Last 11 bytes - easter egg seed
            )
        );

        address computedHyperlaneRootPluginAddress = computeCreate3Address(salt, deployer);
        console2.log("Computed tokentroller address:", computedHyperlaneRootPluginAddress);

        bytes memory initCode = abi.encodePacked(
            type(HyperlaneRootPlugin).creationCode,
            abi.encode(owner, rootMailbox, tokenMetadata, tokenRegistry, tokenEdits)
        );

        hyperlaneRootPlugin = create3(salt, initCode);

        console2.log("Deployments on root chain: ", block.chainid);
        console2.log("Root Plugin:", hyperlaneRootPlugin);

        vm.stopBroadcast();
    }
}
