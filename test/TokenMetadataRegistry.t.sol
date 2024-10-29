// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "src/TokenMetadataRegistry.sol";
import "src/TokentrollerV1.sol";

contract TokenMetadataRegistryTest is Test {
    TokenMetadataRegistry metadataRegistry;
    TokentrollerV1 tokentroller;
    address owner = address(1);
    address nonOwner = address(2);
    address tokenAddress = address(3);
    uint256 chainID = 1;

    function setUp() public {
        tokentroller = new TokentrollerV1(owner);
        metadataRegistry = new TokenMetadataRegistry(address(tokentroller));
    }

    function testAddMetadataField() public {
        vm.prank(address(tokentroller));
        metadataRegistry.addMetadataField(chainID, "website", true);

        TokenMetadataRegistry.MetadataField[] memory fields = metadataRegistry.getMetadataFields(chainID);
        assertEq(fields.length, 1);
        assertEq(fields[0].name, "website");
        assertEq(fields[0].isRequired, true);
        assertEq(fields[0].isActive, true);
    }

    function testCannotAddEmptyFieldName() public {
        vm.prank(address(tokentroller));
        vm.expectRevert("Empty field name");
        metadataRegistry.addMetadataField(chainID, "", true);
    }

    function testCannotAddDuplicateField() public {
        vm.prank(address(tokentroller));
        metadataRegistry.addMetadataField(chainID, "website", true);

        vm.prank(address(tokentroller));
        vm.expectRevert("Field already exists");
        metadataRegistry.addMetadataField(chainID, "website", false);
    }

    function testUpdateMetadataField() public {
        vm.prank(address(tokentroller));
        metadataRegistry.addMetadataField(chainID, "website", true);

        vm.prank(address(tokentroller));
        metadataRegistry.updateMetadataField(chainID, "website", false);

        TokenMetadataRegistry.MetadataField[] memory fields = metadataRegistry.getMetadataFields(chainID);
        assertEq(fields[0].isActive, false);
    }

    function testCannotUpdateNonexistentField() public {
        vm.prank(address(tokentroller));
        vm.expectRevert("Field does not exist");
        metadataRegistry.updateMetadataField(chainID, "nonexistent", false);
    }

    function testSetMetadata() public {
        // First add the field
        vm.prank(address(tokentroller));
        metadataRegistry.addMetadataField(chainID, "website", true);

        // Then set the metadata
        vm.prank(nonOwner);
        metadataRegistry.setMetadata(chainID, tokenAddress, "website", "https://example.com");

        string memory value = metadataRegistry.getMetadata(chainID, tokenAddress, "website");
        assertEq(value, "https://example.com");
    }

    function testCannotSetInvalidField() public {
        vm.prank(nonOwner);
        vm.expectRevert("Invalid field");
        metadataRegistry.setMetadata(chainID, tokenAddress, "nonexistent", "test");
    }

    function testCannotSetInactiveField() public {
        // Add and then deactivate the field
        vm.prank(address(tokentroller));
        metadataRegistry.addMetadataField(chainID, "website", true);
        
        vm.prank(address(tokentroller));
        metadataRegistry.updateMetadataField(chainID, "website", false);

        vm.prank(nonOwner);
        vm.expectRevert("Invalid field");
        metadataRegistry.setMetadata(chainID, tokenAddress, "website", "https://example.com");
    }

    function testUpdateTokentroller() public {
        address newTokentroller = address(4);
        vm.prank(address(tokentroller));
        metadataRegistry.updateTokentroller(newTokentroller);

        assertEq(metadataRegistry.tokentroller(), newTokentroller);
    }

    function testCannotUpdateTokentrollerToZeroAddress() public {
        vm.prank(address(tokentroller));
        vm.expectRevert("Invalid tokentroller address");
        metadataRegistry.updateTokentroller(address(0));
    }

    function testOnlyTokentrollerModifier() public {
        vm.prank(nonOwner);
        vm.expectRevert("Only tokentroller can call");
        metadataRegistry.addMetadataField(chainID, "website", true);
    }
}