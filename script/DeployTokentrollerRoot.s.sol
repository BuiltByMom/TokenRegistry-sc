// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/bridge/TokentrollerRoot.sol";

contract DeployTokentrollerRoot is Script {
    address public tokentrollerRoot;

    function run() external {
        // Load deployer key and addresses
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        address rootMailbox = vm.envAddress("ROOT_MAILBOX");

        vm.startBroadcast(deployerPrivateKey);

        TokentrollerRoot root = new TokentrollerRoot(owner, rootMailbox);
        tokentrollerRoot = address(root);

        console.log("Deployments on root chain: ", block.chainid);
        console.log("Root Tokentroller:", tokentrollerRoot);

        vm.stopBroadcast();
    }
}
