// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "src/TokenRegistry.sol";
import "src/controllers/TokentrollerV1.sol";
import "src/TokenMetadata.sol";
import "src/Helper.sol";

import { Script, console2 } from "forge-std/Script.sol";
import { CreateXScript } from "./CreateXScript.sol";

contract DeployTokenRegistry is Script, CreateXScript {
    function setUp() public withCreateX {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = msg.sender;

        bytes32 registrySalt = bytes32(
            abi.encodePacked(
                deployer, // First 20 bytes - deployer address
                hex"00", // 21st byte - enable cross-chain protection
                bytes11(uint88(109111109)) // Last 11 bytes - easter egg seed
            )
        );

        bytes32 helperSalt = bytes32(
            abi.encodePacked(
                deployer, // First 20 bytes - deployer address
                hex"00", // 21st byte - enable cross-chain protection
                bytes11(uint88(104101108112)) // Last 11 bytes
            )
        );

        console2.log("Registry salt:", uint256(registrySalt));
        console2.log("Helper salt:", uint256(helperSalt));
        console2.log("Deployer:", deployer);

        address computedTokentrollerAddress = computeCreate3Address(registrySalt, deployer);
        console2.log("Computed tokentroller address:", computedTokentrollerAddress);

        // Check if there's any code at the computed address
        bytes memory existingCode = address(computedTokentrollerAddress).code;
        console2.log("Existing code length at computed address:", existingCode.length);

        // Get initial owner from env
        address initialOwner = vm.envAddress("INITIAL_OWNER");
        console2.log("Initial owner:", initialOwner);

        // Create the init code
        bytes memory initCode = abi.encodePacked(type(TokentrollerV1).creationCode, abi.encode(initialOwner));
        console2.log("Init code length:", initCode.length);

        // Try the deployment
        address tokentrollerAddress = create3(registrySalt, initCode);

        // If we get here, deployment was successful
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

        console2.log("TokentrollerV1 deployed at:", tokentrollerAddress);
        console2.log("TokenRegistry deployed at:", tokenRegistryAddress);
        console2.log("TokenMetadata deployed at:", tokenMetadataAddress);
        console2.log("TokenEdits deployed at:", tokenEditsAddress);
        console2.log("Helper deployed at:", helperAddress);

        vm.stopBroadcast();
    }
}
