// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/TokenRegistry.sol";
import "src/interfaces/ITokenRegistry.sol";

contract UploadTokensScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        TokenRegistry registry = TokenRegistry(registryAddress);
        uint256 gasLimit = 500000;

        // Add tokens
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        registry.addToken{ gas: gasLimit }(address(0x123), metadata);

        vm.stopBroadcast();
    }
}
