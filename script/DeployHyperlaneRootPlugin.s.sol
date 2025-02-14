// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/controllers/HyperlaneRootPlugin.sol";

contract DeployHyperlaneRootPlugin is Script {
    address public hyperlaneRootPlugin;

    function run() external {
        // Load deployer key and addresses
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        address rootMailbox = vm.envAddress("HYPERLANE_ROOT_MAILBOX");

        vm.startBroadcast(deployerPrivateKey);

        HyperlaneRootPlugin root = new HyperlaneRootPlugin(owner, rootMailbox);
        hyperlaneRootPlugin = address(root);

        console.log("Deployments on root chain: ", block.chainid);
        console.log("Root Plugin:", hyperlaneRootPlugin);

        vm.stopBroadcast();
    }
}
