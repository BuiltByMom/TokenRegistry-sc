// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/controllers/HyperlaneRootPlugin.sol";
import "../src/controllers/HyperlaneLeafPlugin.sol";
import { CreateXScript } from "./CreateXScript.sol";

contract DeployHyperlaneLeafPlugin is Script, CreateXScript {
    address public hyperlaneLeafPlugin;

    function run() external {
        // Load deployer key and addresses
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        address mailbox = vm.envAddress("HYPERLANE_LEAF_MAILBOX");
        address root = vm.envAddress("HYPERLANE_ROOT_PLUGIN");

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

        address computedHyperlaneLeafPluginAddress = computeCreate3Address(salt, deployer);
        console2.log("Computed hyperlane leaf plugin address:", computedHyperlaneLeafPluginAddress);

        bytes memory initCode = abi.encodePacked(
            type(HyperlaneLeafPlugin).creationCode,
            abi.encode(owner, root, mailbox, tokenMetadata, tokenRegistry, tokenEdits)
        );

        hyperlaneLeafPlugin = create3(salt, initCode);

        console2.log("Deployments on leaf chain: ", block.chainid);
        console2.log("Leaf Plugin:", hyperlaneLeafPlugin);

        vm.stopBroadcast();
    }
}
