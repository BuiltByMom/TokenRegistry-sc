// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/TokenRegistry.sol";
import "src/interfaces/ITokenRegistry.sol";

contract UploadTokensBatchScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        TokenRegistry registry = TokenRegistry(registryAddress);
        uint256 gasLimit = 500000;

        // Add tokens individually
        registry.addToken{ gas: gasLimit }(address(0x123), "https://example.com/logo1.png");

        registry.addToken{ gas: gasLimit }(address(0x456), "https://example.com/logo2.png");

        registry.addToken{ gas: gasLimit }(address(0x789), "https://example.com/logo3.png");

        vm.stopBroadcast();
    }
}
