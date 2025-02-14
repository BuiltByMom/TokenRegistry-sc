// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/controllers/HyperlaneLeafPlugin.sol";

contract DeployHyperlaneLeafPlugin is Script {
    address public hyperlaneLeafPlugin;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        address leafMailbox = vm.envAddress("HYPERLANE_LEAF_MAILBOX");

        vm.startBroadcast(deployerPrivateKey);

        address tokentrollerRootAddr = vm.envAddress("HYPERLANE_ROOT_PLUGIN");
        HyperlaneLeafPlugin leaf = new HyperlaneLeafPlugin(owner, tokentrollerRootAddr, leafMailbox);
        hyperlaneLeafPlugin = address(leaf);

        console.log("Deployments on child chain: ", block.chainid);
        console.log("Leaf Plugin:", hyperlaneLeafPlugin);

        vm.stopBroadcast();
    }
}
