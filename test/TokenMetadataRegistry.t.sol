// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
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
    address nonOwner2 = address(4);
    uint256 chainID = 1;

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
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);

        // First add the field
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        // Then set the metadata
        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, chainID, "website", "https://example.com");

        string memory value = metadataRegistry.getMetadata(tokenAddress, chainID, "website");
        assertEq(value, "https://example.com");
    }

    function testCannotSetInvalidField() public {
        // Add a pending token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);

        vm.prank(nonOwner);
        vm.expectRevert("Invalid field");
        metadataRegistry.setMetadata(tokenAddress, chainID, "nonexistent", "test");
    }

    function testCannotSetInactiveField() public {
        // Add a pending token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);

        // Add and then deactivate the field
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        vm.prank(owner);
        metadataRegistry.updateMetadataField("website", false);

        vm.prank(nonOwner);
        vm.expectRevert("Invalid field");
        metadataRegistry.setMetadata(tokenAddress, chainID, "website", "https://example.com");
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
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);

        // First add the fields
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");
        vm.prank(owner);
        metadataRegistry.addMetadataField("twitter");

        // Set some metadata
        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, chainID, "website", "https://example.com");
        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, chainID, "twitter", "@example");

        // Get all metadata
        TokenMetadataRegistry.MetadataValue[] memory allMetadata = metadataRegistry.getAllMetadata(
            tokenAddress,
            chainID
        );

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
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);

        // Add and set fields
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");
        vm.prank(owner);
        metadataRegistry.addMetadataField("twitter");

        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, chainID, "website", "https://example.com");
        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, chainID, "twitter", "@example");

        // Deactivate one field
        vm.prank(owner);
        metadataRegistry.updateMetadataField("twitter", false);

        // Get all metadata
        TokenMetadataRegistry.MetadataValue[] memory allMetadata = metadataRegistry.getAllMetadata(
            tokenAddress,
            chainID
        );

        // Values should still be present but field marked as inactive
        assertEq(allMetadata.length, 2);
        assertTrue(allMetadata[0].isActive); // website still active
        assertFalse(allMetadata[1].isActive); // twitter now inactive
        assertEq(allMetadata[1].value, "@example"); // value still preserved
    }

    function testSetMetadataForPendingToken() public {
        // Add field first
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        // Then add token and set metadata
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);

        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, chainID, "website", "https://example.com");

        string memory value = metadataRegistry.getMetadata(tokenAddress, chainID, "website");
        assertEq(value, "https://example.com");
    }

    function testCannotSetMetadataForApprovedToken() public {
        // Add field first
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);
        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Try to set metadata directly for approved token
        vm.prank(nonOwner);
        vm.expectRevert("Not authorized");
        metadataRegistry.setMetadata(tokenAddress, chainID, "website", "https://example.com");
    }

    function testMetadataAcrossChains() public {
        // Add field first
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        uint256 chainID2 = 2;

        // Add same token address on different chains
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token Chain 1", "TEST1", "logo1", 18, chainID);
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token Chain 2", "TEST2", "logo2", 18, chainID2);

        // Set different metadata for each chain
        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, chainID, "website", "https://chain1.com");
        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, chainID2, "website", "https://chain2.com");

        // Verify metadata is separate for each chain
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "website"), "https://chain1.com");
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID2, "website"), "https://chain2.com");
    }

    function testGetAllMetadataWithChainId() public {
        // Add field first
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");
        vm.prank(owner);
        metadataRegistry.addMetadataField("twitter");

        // Add token and set metadata
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);

        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, chainID, "website", "https://example.com");
        vm.prank(nonOwner);
        metadataRegistry.setMetadata(tokenAddress, chainID, "twitter", "@example");

        // Get all metadata for specific chain
        TokenMetadataRegistry.MetadataValue[] memory allMetadata = metadataRegistry.getAllMetadata(
            tokenAddress,
            chainID
        );

        assertEq(allMetadata.length, 2);
        assertEq(allMetadata[0].field, "website");
        assertEq(allMetadata[0].value, "https://example.com");
        assertEq(allMetadata[1].field, "twitter");
        assertEq(allMetadata[1].value, "@example");
    }

    function testSetMetadataBatchWithChainId() public {
        // Add fields first
        vm.startPrank(owner);
        metadataRegistry.addMetadataField("website");
        metadataRegistry.addMetadataField("twitter");
        vm.stopPrank();

        // Add token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);

        // Prepare batch metadata
        MetadataInput[] memory inputs = new MetadataInput[](2);
        inputs[0] = MetadataInput({ field: "website", value: "https://example.com" });
        inputs[1] = MetadataInput({ field: "twitter", value: "@example" });

        // Set batch metadata
        vm.prank(nonOwner);
        metadataRegistry.setMetadataBatch(tokenAddress, chainID, inputs);

        // Verify values
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "website"), "https://example.com");
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "twitter"), "@example");
    }

    function testProposeMetadataEdit() public {
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);

        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Create metadata updates
        MetadataInput[] memory updates = new MetadataInput[](1);
        updates[0] = MetadataInput({ field: "website", value: "https://example.com" });

        // Propose edit
        vm.prank(nonOwner);
        metadataRegistry.proposeMetadataEdit(tokenAddress, chainID, updates);

        // Verify tracking
        assertEq(metadataRegistry.tokensMetadataWithEditsLength(chainID), 1);
        assertEq(metadataRegistry.getTokensMetadataWithEdits(chainID, 0), tokenAddress);
        assertEq(metadataRegistry.editCount(chainID, tokenAddress), 1);

        // Get all proposal details in one call
        TokenMetadataRegistry.EditProposalDetails memory proposal = metadataRegistry.getEditProposal(
            chainID,
            tokenAddress,
            1
        );

        // Verify stored proposal
        assertEq(proposal.submitter, nonOwner);
        assertEq(proposal.updates[0].field, "website");
        assertEq(proposal.updates[0].value, "https://example.com");
        assertEq(proposal.chainID, chainID);
        assertTrue(proposal.timestamp > 0);
    }

    function testAcceptMetadataEdit() public {
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);

        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Create metadata updates
        MetadataInput[] memory updates = new MetadataInput[](1);
        updates[0] = MetadataInput({ field: "website", value: "https://example.com" });

        // Propose edit
        vm.prank(nonOwner);
        metadataRegistry.proposeMetadataEdit(tokenAddress, chainID, updates);

        // Accept edit
        vm.prank(owner);
        metadataRegistry.acceptMetadataEdit(tokenAddress, chainID, 1);

        // Verify metadata was updated
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "website"), "https://example.com");

        // Verify tracking was cleared
        assertEq(metadataRegistry.tokensMetadataWithEditsLength(chainID), 0);
        assertEq(metadataRegistry.editCount(chainID, tokenAddress), 0);
    }

    function testAcceptMultipleMetadataEdit() public {
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        vm.prank(owner);
        metadataRegistry.addMetadataField("twitter");

        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);

        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Create metadata updates
        MetadataInput[] memory updates = new MetadataInput[](2);
        updates[0] = MetadataInput({ field: "website", value: "https://example.com" });
        updates[1] = MetadataInput({ field: "twitter", value: "@example" });

        // Propose edit
        vm.prank(nonOwner);
        metadataRegistry.proposeMetadataEdit(tokenAddress, chainID, updates);

        // Accept edit
        vm.prank(owner);
        metadataRegistry.acceptMetadataEdit(tokenAddress, chainID, 1);

        // Verify metadata was updated
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "website"), "https://example.com");
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "twitter"), "@example");
        // Verify tracking was cleared
        assertEq(metadataRegistry.tokensMetadataWithEditsLength(chainID), 0);
        assertEq(metadataRegistry.editCount(chainID, tokenAddress), 0);
    }

    function testRejectMetadataEdit() public {
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);

        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Create metadata updates
        MetadataInput[] memory updates = new MetadataInput[](1);
        updates[0] = MetadataInput({ field: "website", value: "https://example.com" });

        // Propose edit
        vm.prank(nonOwner);
        metadataRegistry.proposeMetadataEdit(tokenAddress, chainID, updates);

        // Reject edit
        vm.prank(owner);
        metadataRegistry.rejectMetadataEdit(tokenAddress, chainID, 1);

        // Verify tracking was cleared
        assertEq(metadataRegistry.tokensMetadataWithEditsLength(chainID), 0);
        assertEq(metadataRegistry.editCount(chainID, tokenAddress), 0);

        // Verify metadata was not updated
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "website"), "");
    }

    function testListMetadataEdits() public {
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");
        vm.prank(owner);
        metadataRegistry.addMetadataField("twitter");

        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TEST", "logo", 18, chainID);

        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Create first edit
        MetadataInput[] memory updates1 = new MetadataInput[](1);
        updates1[0] = MetadataInput({ field: "website", value: "https://example1.com" });

        vm.prank(nonOwner);
        metadataRegistry.proposeMetadataEdit(tokenAddress, chainID, updates1);

        // Create second edit
        MetadataInput[] memory updates2 = new MetadataInput[](1);
        updates2[0] = MetadataInput({ field: "twitter", value: "@example2" });

        vm.prank(nonOwner2);
        metadataRegistry.proposeMetadataEdit(tokenAddress, chainID, updates2);

        // Test listing with pagination
        (TokenMetadataRegistry.MetadataEditInfo[] memory edits, uint256 finalIndex, bool hasMore) = metadataRegistry
            .listAllEdits(chainID, 0, 1);

        assertEq(edits.length, 1);
        assertEq(edits[0].submitter, nonOwner);
        assertEq(edits[0].updates[0].field, "website");
        assertEq(edits[0].updates[0].value, "https://example1.com");
        assertTrue(hasMore);

        // Get second page
        (edits, finalIndex, hasMore) = metadataRegistry.listAllEdits(chainID, 1, 1);

        assertEq(edits.length, 1);
        assertEq(edits[0].submitter, nonOwner2);
        assertEq(edits[0].updates[0].field, "twitter");
        assertEq(edits[0].updates[0].value, "@example2");
        assertFalse(hasMore);
    }

    function testMultipleTokenEdits() public {
        address token2 = address(2);

        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token 2", "TEST", "logo", 18, chainID);
        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        vm.prank(nonOwner);
        tokenRegistry.addToken(token2, "Test Token 2", "TEST", "logo", 18, chainID);
        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, token2);

        // Setup metadata fields
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        // Create edit for first token
        MetadataInput[] memory updates1 = new MetadataInput[](1);
        updates1[0] = MetadataInput({ field: "website", value: "https://example1.com" });

        vm.prank(nonOwner);
        metadataRegistry.proposeMetadataEdit(tokenAddress, chainID, updates1);

        // Create edit for second token
        MetadataInput[] memory updates2 = new MetadataInput[](1);
        updates2[0] = MetadataInput({ field: "website", value: "https://example2.com" });

        vm.prank(nonOwner2);
        metadataRegistry.proposeMetadataEdit(token2, chainID, updates2);

        // Verify tracking
        assertEq(metadataRegistry.tokensMetadataWithEditsLength(chainID), 2);
        assertEq(metadataRegistry.getTokensMetadataWithEdits(chainID, 0), tokenAddress);
        assertEq(metadataRegistry.getTokensMetadataWithEdits(chainID, 1), token2);

        // List all edits
        (TokenMetadataRegistry.MetadataEditInfo[] memory edits, uint256 finalIndex, bool hasMore) = metadataRegistry
            .listAllEdits(chainID, 0, 10);

        assertEq(edits.length, 2);
        assertEq(edits[0].token, tokenAddress);
        assertEq(edits[1].token, token2);
    }

    function testInvalidFieldRejection() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token 2", "TEST", "logo", 18, chainID);
        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Try to propose edit with invalid field
        MetadataInput[] memory updates = new MetadataInput[](1);
        updates[0] = MetadataInput({ field: "invalid_field", value: "test" });

        vm.expectRevert("Invalid field");
        metadataRegistry.proposeMetadataEdit(tokenAddress, chainID, updates);
    }

    function testEmptyUpdatesRejection() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token 2", "TEST", "logo", 18, chainID);
        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Try to propose edit with no updates
        MetadataInput[] memory updates = new MetadataInput[](0);

        vm.expectRevert("No updates provided");
        metadataRegistry.proposeMetadataEdit(tokenAddress, chainID, updates);
    }
}
