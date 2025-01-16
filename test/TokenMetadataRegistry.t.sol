// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/TokenMetadataRegistry.sol";
import "src/TokentrollerV1.sol";
import "src/TokenRegistry.sol";

contract TokenMetadataRegistryTest is Test {
    TokenMetadataRegistry metadataRegistry;
    TokentrollerV1 tokentroller;
    TokenRegistry tokenRegistry;
    address owner = address(1);
    address nonOwner = address(2);
    address tokenAddress = address(3);

    function setUp() public {
        tokentroller = new TokentrollerV1(owner);
        metadataRegistry = TokenMetadataRegistry(tokentroller.metadataRegistry());
        tokenRegistry = TokenRegistry(tokentroller.tokenRegistry());
    }

    function testAddMetadataField() public {
        vm.prank(owner);
        metadataRegistry.addMetadataField("discord");

        TokenMetadataRegistry.MetadataField[] memory fields = metadataRegistry.getMetadataFields();
        assertEq(fields.length, 1);
        assertEq(fields[0].name, "discord");
        assertEq(fields[0].isActive, true);
    }

    function testCannotAddEmptyFieldName() public {
        vm.prank(owner);
        vm.expectRevert("Empty field name");
        metadataRegistry.addMetadataField("");
    }

    function testCannotAddDuplicateField() public {
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        vm.prank(owner);
        vm.expectRevert("Field already exists");
        metadataRegistry.addMetadataField("website");
    }

    function testUpdateMetadataField() public {
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        vm.prank(owner);
        metadataRegistry.updateMetadataField("website", false);

        TokenMetadataRegistry.MetadataField[] memory fields = metadataRegistry.getMetadataFields();
        assertEq(fields[0].isActive, false);
    }

    function testCannotUpdateNonexistentField() public {
        vm.prank(owner);
        vm.expectRevert("Field does not exist");
        metadataRegistry.updateMetadataField("nonexistent", false);
    }

    function testSetMetadata() public {
        // First add a pending token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "logo");

        // First add the field
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        // Then set the metadata
        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, "website", "https://example.com");

        string memory value = metadataRegistry.getMetadata(tokenAddress, "website");
        assertEq(value, "https://example.com");
    }

    function testCannotSetInvalidField() public {
        // Add a pending token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "logo");

        vm.prank(nonOwner);
        vm.expectRevert("Invalid field");
        metadataRegistry.setMetadata(tokenAddress, "nonexistent", "test");
    }

    function testCannotSetInactiveField() public {
        // Add a pending token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "logo");

        // Add and then deactivate the field
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        vm.prank(owner);
        metadataRegistry.updateMetadataField("website", false);

        vm.prank(nonOwner);
        vm.expectRevert("Invalid field");
        metadataRegistry.setMetadata(tokenAddress, "website", "https://example.com");
    }

    function testUpdateTokentroller() public {
        address newTokentroller = address(4);
        vm.prank(address(tokentroller));
        metadataRegistry.updateTokentroller(newTokentroller);

        assertEq(metadataRegistry.tokentroller(), newTokentroller);
    }

    function testOnlyTokentrollerModifier() public {
        vm.prank(nonOwner);
        vm.expectRevert("Not authorized");
        metadataRegistry.addMetadataField("website");
    }

    function testGetAllMetadata() public {
        // Add a pending token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "logo");

        // First add the fields
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");
        vm.prank(owner);
        metadataRegistry.addMetadataField("twitter");

        // Set some metadata
        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, "website", "https://example.com");
        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, "twitter", "@example");

        // Get all metadata
        TokenMetadataRegistry.MetadataValue[] memory allMetadata = metadataRegistry.getAllMetadata(tokenAddress);

        // Verify the results
        assertEq(allMetadata.length, 2);

        // Check fields
        assertEq(allMetadata[0].field, "website");
        assertEq(allMetadata[0].value, "https://example.com");
        assertTrue(allMetadata[0].isActive);

        assertEq(allMetadata[1].field, "twitter");
        assertEq(allMetadata[1].value, "@example");
        assertTrue(allMetadata[1].isActive);
    }

    function testGetAllMetadataWithInactiveField() public {
        // Add a pending token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "logo");

        // Add and set fields
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");
        vm.prank(owner);
        metadataRegistry.addMetadataField("twitter");

        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, "website", "https://example.com");
        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, "twitter", "@example");

        // Deactivate one field
        vm.prank(owner);
        metadataRegistry.updateMetadataField("twitter", false);

        // Get all metadata
        TokenMetadataRegistry.MetadataValue[] memory allMetadata = metadataRegistry.getAllMetadata(tokenAddress);

        // Values should still be present but field marked as inactive
        assertEq(allMetadata.length, 2);
        assertTrue(allMetadata[0].isActive); // website still active
        assertFalse(allMetadata[1].isActive); // twitter now inactive
        assertEq(allMetadata[1].value, "@example"); // value still preserved
    }

    function testSetMetadataBatch() public {
        // Add fields first
        vm.startPrank(owner);
        metadataRegistry.addMetadataField("website");
        metadataRegistry.addMetadataField("twitter");
        vm.stopPrank();

        // Add token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "logo");

        // Prepare batch metadata
        MetadataInput[] memory inputs = new MetadataInput[](2);
        inputs[0] = MetadataInput({ field: "website", value: "https://example.com" });
        inputs[1] = MetadataInput({ field: "twitter", value: "@example" });

        // Set batch metadata
        vm.prank(nonOwner);
        metadataRegistry.setMetadataBatch(tokenAddress, inputs);

        // Verify values
        assertEq(metadataRegistry.getMetadata(tokenAddress, "website"), "https://example.com");
        assertEq(metadataRegistry.getMetadata(tokenAddress, "twitter"), "@example");
    }

    function testIsValidField() public {
        // Test non-existent field
        assertFalse(metadataRegistry.isValidField("nonexistent"));

        // Add a field and test
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");
        assertTrue(metadataRegistry.isValidField("website"));

        // Deactivate field and test
        vm.prank(owner);
        metadataRegistry.updateMetadataField("website", false);
        assertFalse(metadataRegistry.isValidField("website"));
    }
}
