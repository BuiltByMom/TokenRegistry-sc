// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/TokenRegistryEdits.sol";
import "src/TokenRegistry.sol";
import "src/TokentrollerV1.sol";
import "src/interfaces/ITokenRegistry.sol";

contract TokenRegistryEditsTest is Test {
    TokenRegistryEdits tokenRegistryEdits;
    TokenRegistry tokenRegistry;
    TokentrollerV1 tokentroller;
    TokenMetadataRegistry metadataRegistry;
    address owner = address(1);
    address nonOwner = address(2);
    address nonOwner2 = address(3);
    address tokenAddress = address(4);
    uint256 chainID = 1;

    event TokenEditProposed(address indexed contractAddress, uint256 indexed chainID, uint256 editIndex);
    event TokenEditAccepted(address indexed contractAddress, uint256 indexed chainID, uint256 editIndex);
    event TokenEditRejected(address indexed contractAddress, uint256 indexed chainID, uint256 editIndex, string reason);

    function setUp() public {
        tokentroller = new TokentrollerV1(owner);
        tokenRegistry = TokenRegistry(tokentroller.tokenRegistry());
        metadataRegistry = TokenMetadataRegistry(tokentroller.metadataRegistry());
        tokenRegistryEdits = TokenRegistryEdits(tokentroller.tokenRegistryEdits());
    }

    function testProposeEdit() public {
        // First add and approve a token
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Now propose an edit
        vm.prank(nonOwner);
        tokenRegistryEdits.proposeEdit(
            tokenAddress,
            "Updated Token",
            "UTK",
            "https://example.com/new_logo.png",
            9,
            chainID
        );

        // Check that the edit is stored
        (
            address submitter,
            uint256 chainId,
            string memory name,
            string memory symbol,
            string memory logoURI,
            uint8 decimals,
            uint256 timestamp
        ) = tokenRegistryEdits.editsOnTokens(chainID, tokenAddress, 1);

        assertEq(name, "Updated Token", "Name should be in edit");
        assertEq(symbol, "UTK", "Symbol should be in edit");
        assertEq(logoURI, "https://example.com/new_logo.png", "Logo URI should be in edit");
        assertEq(decimals, 9, "Decimals should be in edit");
        assertEq(timestamp, block.timestamp, "Timestamp should be in edit");
    }

    function testCannotProposeEditForNonApprovedToken() public {
        // Add token but don't approve it
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);

        // Try to propose edit for pending token
        vm.prank(nonOwner);
        vm.expectRevert("Token must be approved");
        tokenRegistryEdits.proposeEdit(
            tokenAddress,
            "Updated Token",
            "UTK",
            "https://example.com/new_logo.png",
            9,
            chainID
        );
    }

    function testAcceptEdit() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Create edit
        vm.prank(nonOwner);
        tokenRegistryEdits.proposeEdit(
            tokenAddress,
            "Updated Token",
            "UTK",
            "https://example.com/new_logo.png",
            9,
            chainID
        );

        // Accept the edit
        vm.prank(owner);
        tokenRegistryEdits.acceptEdit(tokenAddress, 1, chainID);

        // Verify token was updated
        (
            address contractAddress,
            address submitter,
            string memory name,
            string memory logoURI,
            string memory symbol,
            uint8 decimals,
            uint256 chainId
        ) = tokenRegistry.tokens(chainID, tokenAddress, 1);

        assertEq(name, "Updated Token", "Name should be updated");
        assertEq(symbol, "UTK", "Symbol should be updated");
        assertEq(logoURI, "https://example.com/new_logo.png", "Logo URI should be updated");
        assertEq(decimals, 9, "Decimals should be updated");
    }

    function testRejectEdit() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Create edit
        vm.prank(nonOwner);
        tokenRegistryEdits.proposeEdit(
            tokenAddress,
            "Updated Token",
            "UTK",
            "https://example.com/new_logo.png",
            9,
            chainID
        );

        // Reject the edit
        vm.prank(owner);
        tokenRegistryEdits.rejectEdit(tokenAddress, 1, chainID, "Invalid token symbol");

        // Verify edit was cleared
        (address submitter, , , , , , ) = tokenRegistryEdits.editsOnTokens(chainID, tokenAddress, 1);
        assertEq(submitter, address(0), "Edit should be cleared");
    }

    function testCannotRejectEditWithoutPermission() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Create edit
        vm.prank(nonOwner);
        tokenRegistryEdits.proposeEdit(
            tokenAddress,
            "Updated Token",
            "UTK",
            "https://example.com/new_logo.png",
            9,
            chainID
        );

        // Try to reject without permission
        vm.prank(nonOwner);
        vm.expectRevert("Not authorized to reject edit");
        tokenRegistryEdits.rejectEdit(tokenAddress, 1, chainID, "Invalid token symbol");
    }

    function testAcceptEditClearsOtherEdits() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Create multiple edits
        vm.prank(nonOwner);
        tokenRegistryEdits.proposeEdit(
            tokenAddress,
            "Updated Token 1",
            "UT1",
            "https://example.com/logo1.png",
            9,
            chainID
        );
        vm.prank(nonOwner);
        tokenRegistryEdits.proposeEdit(
            tokenAddress,
            "Updated Token 2",
            "UT2",
            "https://example.com/logo2.png",
            12,
            chainID
        );

        // Accept first edit
        vm.prank(owner);
        tokenRegistryEdits.acceptEdit(tokenAddress, 1, chainID);

        // Verify second edit was cleared
        (address submitter, , , , , , ) = tokenRegistryEdits.editsOnTokens(chainID, tokenAddress, 2);
        assertEq(submitter, address(0), "Second edit should be cleared");

        // Verify edit count was reset
        assertEq(tokenRegistryEdits.editCount(chainID, tokenAddress), 0, "Edit count should be reset");
    }

    function testEditTracking() public {
        // Add and approve a token first
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Verify no edits initially
        assertEq(tokenRegistryEdits.getTokensWithEditsCount(chainID), 0);

        // Create first edit
        vm.prank(nonOwner);
        tokenRegistryEdits.proposeEdit(
            tokenAddress,
            "Updated Token",
            "UTK",
            "https://example.com/new_logo.png",
            9,
            chainID
        );

        // Verify token is tracked
        assertEq(tokenRegistryEdits.getTokensWithEditsCount(chainID), 1);
        assertEq(tokenRegistryEdits.getTokenWithEdits(chainID, 0), tokenAddress);
        assertEq(tokenRegistryEdits.editCount(chainID, tokenAddress), 1);

        // Create second edit
        vm.prank(nonOwner2);
        tokenRegistryEdits.proposeEdit(
            tokenAddress,
            "Updated Token 2",
            "UTK2",
            "https://example.com/new_logo2.png",
            12,
            chainID
        );

        // Verify tracking remains correct
        assertEq(tokenRegistryEdits.getTokensWithEditsCount(chainID), 1);
        assertEq(tokenRegistryEdits.editCount(chainID, tokenAddress), 2);
    }

    function testListEdits() public {
        // Add and approve a token
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Create multiple edits
        vm.prank(nonOwner);
        tokenRegistryEdits.proposeEdit(
            tokenAddress,
            "Updated Token 1",
            "UT1",
            "https://example.com/logo1.png",
            9,
            chainID
        );
        vm.prank(nonOwner2);
        tokenRegistryEdits.proposeEdit(
            tokenAddress,
            "Updated Token 2",
            "UT2",
            "https://example.com/logo2.png",
            12,
            chainID
        );

        // Test listing with pagination
        (TokenRegistryEdits.TokenEdit[] memory edits, uint256 finalIndex, bool hasMore) = tokenRegistryEdits.listEdits(
            chainID,
            0,
            1
        );

        assertEq(edits.length, 1);
        assertEq(edits[0].name, "Updated Token 1");
        assertTrue(hasMore);

        // Get second page
        (edits, finalIndex, hasMore) = tokenRegistryEdits.listEdits(chainID, 1, 1);

        assertEq(edits.length, 1);
        assertEq(edits[0].name, "Updated Token 2");
        assertFalse(hasMore);
    }

    function testProposeEditWithMetadata() public {
        // Add and approve token first
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TEST", "logo", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Setup metadata field
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        // Prepare metadata updates
        MetadataInput[] memory updates = new MetadataInput[](1);
        updates[0] = MetadataInput({ field: "website", value: "https://example.com" });

        // Propose both edits
        vm.prank(nonOwner);
        tokenRegistryEdits.proposeEditWithMetadata(
            tokenAddress,
            "Updated Token",
            "UTEST",
            "newlogo",
            18,
            chainID,
            updates
        );

        // Verify token edit was proposed
        (TokenRegistryEdits.TokenEdit[] memory edits, uint256 finalIndex, bool hasMore) = tokenRegistryEdits.listEdits(
            chainID,
            0,
            1
        );
        TokenRegistryEdits.TokenEdit memory tokenEdit = edits[0];
        assertEq(tokenEdit.name, "Updated Token");
        assertEq(tokenEdit.symbol, "UTEST");

        // Verify metadata edit was proposed
        (
            TokenMetadataRegistry.MetadataEditInfo[] memory metadataEdits,
            uint256 metadataFinalIndex,
            bool metadataHasMore
        ) = metadataRegistry.listAllEdits(chainID, 0, 1);

        assertEq(metadataEdits.length, 1);
        assertEq(metadataEdits[0].updates[0].value, "https://example.com");
    }
}
