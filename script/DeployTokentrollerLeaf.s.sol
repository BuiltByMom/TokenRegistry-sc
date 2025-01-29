// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/bridge/TokentrollerLeaf.sol";

contract DeployTokentrollerLeaf is Script {
    address public tokentrollerRoot;
    address public tokentrollerLeaf;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        address leafMailbox = vm.envAddress("LEAF_MAILBOX");

        vm.startBroadcast(deployerPrivateKey);

        address tokentrollerRootAddr = vm.envAddress("TOKENTROLLER_ROOT");
        TokentrollerLeaf leaf = new TokentrollerLeaf(owner, tokentrollerRootAddr, leafMailbox);
        tokentrollerLeaf = address(leaf);

        console.log("Deployments on child chain: ", block.chainid);
        console.log("Leaf Tokentroller:", tokentrollerLeaf);

        vm.stopBroadcast();
    }
}
