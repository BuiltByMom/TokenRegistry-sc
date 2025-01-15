// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/TokenMetadataEdits.sol";
import "src/TokenMetadataRegistry.sol";
import "src/TokenRegistry.sol";
import "src/TokentrollerV1.sol";

contract TokenMetadataEditsTest is Test {
    TokenMetadataEdits metadataEdits;
    TokenMetadataRegistry metadataRegistry;
    TokenRegistry tokenRegistry;
    TokentrollerV1 tokentroller;
    address owner = address(1);
    address nonOwner = address(2);
    address nonOwner2 = address(3);
    address tokenAddress = address(4);
    uint256 chainID = 1;

    event MetadataEditProposed(
        address indexed token,
        uint256 indexed chainID,
        address submitter,
        MetadataInput[] updates
    );
    event MetadataEditAccepted(address indexed token, uint256 indexed editIndex, uint256 chainID);
    event MetadataEditRejected(address indexed token, uint256 indexed editIndex, uint256 chainID, string reason);

    function setUp() public {
        tokentroller = new TokentrollerV1(owner);
        tokenRegistry = TokenRegistry(tokentroller.tokenRegistry());
        metadataRegistry = TokenMetadataRegistry(tokentroller.metadataRegistry());
        metadataEdits = TokenMetadataEdits(tokentroller.metadataEdits());
    }

    function testProposeMetadataEdit() public {
        // Add field first
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TEST", "logo", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Create metadata updates
        MetadataInput[] memory updates = new MetadataInput[](1);
        updates[0] = MetadataInput({ field: "website", value: "https://example.com" });

        // Propose edit
        vm.prank(nonOwner);
        metadataEdits.proposeMetadataEdit(tokenAddress, chainID, updates);

        // Verify tracking
        assertEq(metadataEdits.tokensMetadataWithEditsLength(chainID), 1);
        assertEq(metadataEdits.getTokensMetadataWithEdits(chainID, 0), tokenAddress);
        assertEq(metadataEdits.getEditCount(chainID, tokenAddress), 1);

        // Get proposal details
        ITokenMetadataEdits.MetadataEditProposal memory proposal = metadataEdits.getEditProposal(
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
        // Add field first
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TEST", "logo", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Create metadata updates
        MetadataInput[] memory updates = new MetadataInput[](1);
        updates[0] = MetadataInput({ field: "website", value: "https://example.com" });

        // Propose edit
        vm.prank(nonOwner);
        metadataEdits.proposeMetadataEdit(tokenAddress, chainID, updates);

        // Accept edit
        vm.prank(owner);
        metadataEdits.acceptMetadataEdit(tokenAddress, chainID, 1);

        // Verify metadata was updated
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "website"), "https://example.com");

        // Verify tracking was cleared
        assertEq(metadataEdits.tokensMetadataWithEditsLength(chainID), 0);
        assertEq(metadataEdits.getEditCount(chainID, tokenAddress), 0);
    }

    function testAcceptMultipleMetadataEdit() public {
        // Add fields first
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");
        vm.prank(owner);
        metadataRegistry.addMetadataField("twitter");

        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TEST", "logo", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Create metadata updates
        MetadataInput[] memory updates = new MetadataInput[](2);
        updates[0] = MetadataInput({ field: "website", value: "https://example.com" });
        updates[1] = MetadataInput({ field: "twitter", value: "@example" });

        // Propose edit
        vm.prank(nonOwner);
        metadataEdits.proposeMetadataEdit(tokenAddress, chainID, updates);

        // Accept edit
        vm.prank(owner);
        metadataEdits.acceptMetadataEdit(tokenAddress, chainID, 1);

        // Verify metadata was updated
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "website"), "https://example.com");
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "twitter"), "@example");

        // Verify tracking was cleared
        assertEq(metadataEdits.tokensMetadataWithEditsLength(chainID), 0);
        assertEq(metadataEdits.getEditCount(chainID, tokenAddress), 0);
    }

    function testRejectMetadataEdit() public {
        // Add field first
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TEST", "logo", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Create metadata updates
        MetadataInput[] memory updates = new MetadataInput[](1);
        updates[0] = MetadataInput({ field: "website", value: "https://example.com" });

        // Propose edit
        vm.prank(nonOwner);
        metadataEdits.proposeMetadataEdit(tokenAddress, chainID, updates);

        // Reject edit
        vm.prank(owner);
        metadataEdits.rejectMetadataEdit(tokenAddress, chainID, 1, "Invalid website URL");

        // Verify tracking was cleared
        assertEq(metadataEdits.tokensMetadataWithEditsLength(chainID), 0);
        assertEq(metadataEdits.getEditCount(chainID, tokenAddress), 0);

        // Verify metadata was not updated
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "website"), "");
    }

    function testListMetadataEdits() public {
        // Add fields first
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");
        vm.prank(owner);
        metadataRegistry.addMetadataField("twitter");

        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TEST", "logo", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Create first edit
        MetadataInput[] memory updates1 = new MetadataInput[](1);
        updates1[0] = MetadataInput({ field: "website", value: "https://example1.com" });

        vm.prank(nonOwner);
        metadataEdits.proposeMetadataEdit(tokenAddress, chainID, updates1);

        // Create second edit
        MetadataInput[] memory updates2 = new MetadataInput[](1);
        updates2[0] = MetadataInput({ field: "twitter", value: "@example2" });

        vm.prank(nonOwner2);
        metadataEdits.proposeMetadataEdit(tokenAddress, chainID, updates2);

        // Test listing with pagination
        (ITokenMetadataEdits.MetadataEditInfo[] memory edits, uint256 finalIndex, bool hasMore) = metadataEdits
            .listAllEdits(chainID, 0, 1);

        assertEq(edits.length, 1);
        assertEq(edits[0].submitter, nonOwner);
        assertEq(edits[0].updates[0].field, "website");
        assertEq(edits[0].updates[0].value, "https://example1.com");
        assertTrue(hasMore);

        // Get second page
        (edits, finalIndex, hasMore) = metadataEdits.listAllEdits(chainID, 1, 1);

        assertEq(edits.length, 1);
        assertEq(edits[0].submitter, nonOwner2);
        assertEq(edits[0].updates[0].field, "twitter");
        assertEq(edits[0].updates[0].value, "@example2");
        assertFalse(hasMore);
    }

    function testMultipleTokenEdits() public {
        address token2 = address(5);

        // Add and approve tokens
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token 1", "TEST1", "logo", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, token2, "Test Token 2", "TEST2", "logo", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, token2);

        // Setup metadata fields
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        // Create edit for first token
        MetadataInput[] memory updates1 = new MetadataInput[](1);
        updates1[0] = MetadataInput({ field: "website", value: "https://example1.com" });

        vm.prank(nonOwner);
        metadataEdits.proposeMetadataEdit(tokenAddress, chainID, updates1);

        // Create edit for second token
        MetadataInput[] memory updates2 = new MetadataInput[](1);
        updates2[0] = MetadataInput({ field: "website", value: "https://example2.com" });

        vm.prank(nonOwner2);
        metadataEdits.proposeMetadataEdit(token2, chainID, updates2);

        // Verify tracking
        assertEq(metadataEdits.tokensMetadataWithEditsLength(chainID), 2);
        assertEq(metadataEdits.getTokensMetadataWithEdits(chainID, 0), tokenAddress);
        assertEq(metadataEdits.getTokensMetadataWithEdits(chainID, 1), token2);

        // List all edits
        (ITokenMetadataEdits.MetadataEditInfo[] memory edits, uint256 finalIndex, bool hasMore) = metadataEdits
            .listAllEdits(chainID, 0, 10);

        assertEq(edits.length, 2);
        assertEq(edits[0].token, tokenAddress);
        assertEq(edits[1].token, token2);
    }

    function testInvalidFieldRejection() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TEST", "logo", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Try to propose edit with invalid field
        MetadataInput[] memory updates = new MetadataInput[](1);
        updates[0] = MetadataInput({ field: "invalid_field", value: "test" });

        vm.prank(nonOwner);
        vm.expectRevert("Invalid field");
        metadataEdits.proposeMetadataEdit(tokenAddress, chainID, updates);
    }

    function testEmptyUpdatesRejection() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TEST", "logo", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Try to propose edit with no updates
        MetadataInput[] memory updates = new MetadataInput[](0);

        vm.prank(nonOwner);
        vm.expectRevert("No updates provided");
        metadataEdits.proposeMetadataEdit(tokenAddress, chainID, updates);
    }
}
