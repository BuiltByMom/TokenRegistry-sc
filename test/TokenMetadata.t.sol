// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/TokenMetadata.sol";
import "src/controllers/TokentrollerV1.sol";
import "src/TokenRegistry.sol";
import "./mocks/MockERC20.sol";

contract TokenMetadataTest is Test {
    TokenMetadata tokenMetadata;
    TokentrollerV1 tokentroller;
    TokenRegistry tokenRegistry;
    address owner = address(1);
    address nonOwner = address(2);
    MockERC20 token;

    function setUp() public {
        tokentroller = new TokentrollerV1(owner);
        tokenMetadata = TokenMetadata(tokentroller.tokenMetadata());
        tokenRegistry = TokenRegistry(tokentroller.tokenRegistry());
        token = new MockERC20("Test Token", "TEST", 18);
    }

    function testAddMetadataField() public {
        vm.prank(owner);
        tokenMetadata.addField("discord");

        ITokenMetadata.MetadataField[] memory fields = tokenMetadata.getMetadataFields();
        assertEq(fields.length, 2);
        assertEq(fields[1].name, "discord");
        assertEq(fields[1].isActive, true);
    }

    function testCannotAddEmptyFieldName() public {
        vm.prank(owner);
        vm.expectRevert("Empty field name");
        tokenMetadata.addField("");
    }

    function testCannotAddDuplicateField() public {
        vm.prank(owner);
        tokenMetadata.addField("website");

        vm.prank(owner);
        vm.expectRevert("Field already exists");
        tokenMetadata.addField("website");
    }

    function testUpdateMetadataField() public {
        vm.prank(owner);
        tokenMetadata.addField("website");

        vm.prank(owner);
        tokenMetadata.updateField("website", false, false);

        ITokenMetadata.MetadataField[] memory fields = tokenMetadata.getMetadataFields();
        assertEq(fields[1].isActive, false);
    }

    function testCannotUpdateNonexistentField() public {
        vm.prank(owner);
        vm.expectRevert("Field does not exist");
        tokenMetadata.updateField("nonexistent", false, false);
    }

    function testCannotSetInvalidField() public {
        // Add a pending token with required logoURI
        vm.prank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(token), metadata);

        // Try to update with a non-existent field
        vm.startPrank(address(tokenRegistry));
        MetadataInput[] memory invalidMetadata = new MetadataInput[](1);
        invalidMetadata[0] = MetadataInput({ field: "nonexistent", value: "some value" });
        vm.expectRevert("Field does not exist");
        tokenMetadata.updateMetadata(address(token), invalidMetadata);
        vm.stopPrank();
    }

    function testCannotSetInactiveField() public {
        // Add a pending token with required logoURI
        vm.prank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        tokenRegistry.addToken(address(token), metadata);

        // Add and then deactivate the field
        vm.startPrank(owner);
        tokenMetadata.addField("website");
        tokenMetadata.updateField("website", false, false);
        vm.stopPrank();

        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "website", value: "https://example.com" });

        vm.prank(address(tokenRegistry));
        vm.expectRevert("Invalid field");
        tokenMetadata.updateMetadata(address(token), metadata2);
    }

    function testUpdateTokentroller() public {
        address newTokentroller = address(4);
        vm.prank(address(tokentroller));
        tokenMetadata.updateTokentroller(newTokentroller);

        assertEq(tokenMetadata.tokentroller(), newTokentroller);
    }

    function testOnlyTokentrollerModifier() public {
        vm.prank(nonOwner);
        vm.expectRevert("Not authorized to add metadata field");
        tokenMetadata.addField("website");
    }

    function testGetAllMetadata() public {
        // Add a pending token
        vm.prank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(token), metadata);

        // First add the fields
        vm.prank(owner);
        tokenMetadata.addField("website");
        vm.prank(owner);
        tokenMetadata.addField("twitter");

        // Set some metadata

        MetadataInput[] memory metadata2 = new MetadataInput[](2);
        metadata2[0] = MetadataInput({ field: "website", value: "https://example.com" });
        metadata2[1] = MetadataInput({ field: "twitter", value: "@example" });
        vm.prank(address(tokenRegistry));
        tokenMetadata.updateMetadata(address(token), metadata2);

        // Get all metadata
        MetadataValue[] memory allMetadata = tokenMetadata.getAllMetadata(address(token));

        // Verify the results
        assertEq(allMetadata.length, 3);

        // Check fields
        assertEq(allMetadata[0].field, "logoURI");
        assertEq(allMetadata[0].value, "https://example.com/logo.png");
        assertTrue(allMetadata[0].isActive);

        assertEq(allMetadata[1].field, "website");
        assertEq(allMetadata[1].value, "https://example.com");
        assertTrue(allMetadata[1].isActive);

        assertEq(allMetadata[2].field, "twitter");
        assertEq(allMetadata[2].value, "@example");
        assertTrue(allMetadata[2].isActive);
    }

    function testGetAllMetadataWithInactiveField() public {
        // Add a pending token
        vm.prank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(token), metadata);

        // Add and set fields
        vm.prank(owner);
        tokenMetadata.addField("website");
        vm.prank(owner);
        tokenMetadata.addField("twitter");

        MetadataInput[] memory metadata2 = new MetadataInput[](2);
        metadata2[0] = MetadataInput({ field: "website", value: "https://example.com" });
        metadata2[1] = MetadataInput({ field: "twitter", value: "@example" });

        vm.prank(address(tokenRegistry));
        tokenMetadata.updateMetadata(address(token), metadata2);

        // Deactivate one field
        vm.prank(owner);
        tokenMetadata.updateField("twitter", false, false);

        // Get all metadata
        MetadataValue[] memory allMetadata = tokenMetadata.getAllMetadata(address(token));

        // Values should still be present but field marked as inactive
        assertEq(allMetadata.length, 3);
        assertTrue(allMetadata[0].isActive);
        assertTrue(allMetadata[1].isActive);
        assertFalse(allMetadata[2].isActive);
        assertEq(allMetadata[2].value, "@example");
    }

    function testGetField() public {
        // Test non-existent field
        assertFalse(tokenMetadata.getField("nonexistent").isActive);

        // Add a field and test
        vm.prank(owner);
        tokenMetadata.addField("website", true);
        assertTrue(tokenMetadata.getField("website").isActive);
        assertTrue(tokenMetadata.getField("website").isRequired);

        // Deactivate field and test
        vm.prank(owner);
        tokenMetadata.updateField("website", false, false);
        assertFalse(tokenMetadata.getField("website").isActive);
        assertFalse(tokenMetadata.getField("website").isRequired);
    }
}
