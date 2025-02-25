// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "src/TokenEdits.sol";
import "src/controllers/TokentrollerV1.sol";
import "src/TokenMetadata.sol";
import "src/Helper.sol";

import { Script, console2 } from "forge-std/Script.sol";
import { CreateXScript } from "./CreateXScript.sol";

contract DeployHelper is Script, CreateXScript {
    function setUp() public withCreateX {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = msg.sender;

        bytes32 helperSalt = bytes32(
            abi.encodePacked(
                deployer, // First 20 bytes - deployer address
                hex"00", // 21st byte - enable cross-chain protection
                bytes11(uint88(104101108117)) // Last 11 bytes
            )
        );

        console2.log("Helper salt:", uint256(helperSalt));
        console2.log("Deployer:", deployer);

        address tokentrollerAddress = vm.envAddress("TOKENTROLLER_ADDRESS");
        TokentrollerV1 tokentroller = TokentrollerV1(tokentrollerAddress);

        // Get deployed contract addresses
        address tokenRegistryAddress = tokentroller.tokenRegistry();
        address tokenMetadataAddress = tokentroller.tokenMetadata();
        address tokenEditsAddress = tokentroller.tokenEdits();

        address computedHelperAddress = computeCreate3Address(helperSalt, deployer);
        console2.log("Computed helper address:", computedHelperAddress);

        address helperAddress = create3(
            helperSalt,
            abi.encodePacked(
                type(Helper).creationCode,
                abi.encode(tokenRegistryAddress, tokenEditsAddress, tokenMetadataAddress, tokentrollerAddress)
            )
        );

        TokentrollerV1(tokentrollerAddress).addTrustedHelper(helperAddress);
        console2.log("Helper added as a trusted helper");

        console2.log("TokentrollerV1 stayed at:", tokentrollerAddress);
        console2.log("TokenRegistry stayed at:", tokenRegistryAddress);
        console2.log("TokenMetadata stayed at:", tokenMetadataAddress);
        console2.log("TokenEdits stayed at:", tokenEditsAddress);
        console2.log("Helper deployed at:", helperAddress);

        vm.stopBroadcast();
    }
}
