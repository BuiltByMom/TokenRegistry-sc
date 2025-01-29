// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../test/mocks/MockERC20.sol";
import "../src/TokenRegistry.sol";
import "../src/bridge/TokentrollerLeaf.sol";

contract TestTokenDeployment is MockERC20 {
    constructor() MockERC20("Test Token", "TEST", 18) {}
}

contract DeployTestToken is Script {
    address public testToken;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tokentrollerLeaf = vm.envAddress("TOKENTROLLER_LEAF");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy test token
        TestTokenDeployment token = new TestTokenDeployment();
        testToken = address(token);
        console.log("Deployed Test Token at:", address(token));

        // Get TokenRegistry from leaf tokentroller
        TokentrollerLeaf leaf = TokentrollerLeaf(tokentrollerLeaf);
        address registry = leaf.tokenRegistry();
        console.log("TokenRegistry at:", registry);

        // Add token to registry
        TokenRegistry(registry).addToken(address(token), new MetadataInput[](0));
        console.log("Added token to registry");

        vm.stopBroadcast();
    }
}
