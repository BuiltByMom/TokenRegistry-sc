// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/TokenEdits.sol";
import "src/TokenRegistry.sol";
import "src/TokentrollerV1.sol";
import "src/interfaces/ITokenRegistry.sol";

contract TokenEditsTest is Test {
    TokenEdits tokenEdits;
    TokenRegistry tokenRegistry;
    TokentrollerV1 tokentroller;
    address owner = address(1);
    address nonOwner = address(2);
    address nonOwner2 = address(3);
    address tokenAddress = address(4);

    event TokenEditProposed(address indexed contractAddress, uint256 editIndex);
    event TokenEditAccepted(address indexed contractAddress, uint256 editIndex);
    event TokenEditRejected(address indexed contractAddress, uint256 editIndex, string reason);

    function setUp() public {
        tokentroller = new TokentrollerV1(owner);
        tokenRegistry = TokenRegistry(tokentroller.tokenRegistry());
        tokenEdits = TokenEdits(tokentroller.tokenEdits());
    }

    function testProposeEdit() public {
        // First add and approve a token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(tokenAddress);

        // Now propose an edit
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9);

        // Check that the edit is stored
        (
            address submitter,
            string memory name,
            string memory symbol,
            string memory logoURI,
            uint8 decimals,
            uint256 timestamp
        ) = tokenEdits.editsOnTokens(tokenAddress, 1);

        assertEq(name, "Updated Token", "Name should be in edit");
        assertEq(symbol, "UTK", "Symbol should be in edit");
        assertEq(logoURI, "https://example.com/new_logo.png", "Logo URI should be in edit");
        assertEq(decimals, 9, "Decimals should be in edit");
        assertEq(timestamp, block.timestamp, "Timestamp should be in edit");
    }

    function testCannotProposeEditForNonApprovedToken() public {
        // Add token but don't approve it
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);

        // Try to propose edit for pending token
        vm.prank(nonOwner);
        vm.expectRevert("Not authorized to propose edit");
        tokenEdits.proposeEdit(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9);
    }

    function testAcceptEdit() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(tokenAddress);

        // Create edit
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9);

        // Accept the edit
        vm.prank(owner);
        tokenEdits.acceptEdit(tokenAddress, 1);

        // Verify token was updated
        (
            address contractAddress,
            address submitter,
            string memory name,
            string memory logoURI,
            string memory symbol,
            uint8 decimals
        ) = tokenRegistry.tokens(TokenStatus.APPROVED, tokenAddress);

        assertEq(name, "Updated Token", "Name should be updated");
        assertEq(symbol, "UTK", "Symbol should be updated");
        assertEq(logoURI, "https://example.com/new_logo.png", "Logo URI should be updated");
        assertEq(decimals, 9, "Decimals should be updated");
    }

    function testRejectEdit() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(tokenAddress);

        // Create edit
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9);

        // Reject the edit
        vm.prank(owner);
        tokenEdits.rejectEdit(tokenAddress, 1, "Invalid token symbol");

        // Verify edit was cleared
        (address submitter, , , , , ) = tokenEdits.editsOnTokens(tokenAddress, 1);
        assertEq(submitter, address(0), "Edit should be cleared");
    }

    function testCannotRejectEditWithoutPermission() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(tokenAddress);

        // Create edit
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9);

        // Try to reject without permission
        vm.prank(nonOwner);
        vm.expectRevert("Not authorized to reject edit");
        tokenEdits.rejectEdit(tokenAddress, 1, "Invalid token symbol");
    }

    function testAcceptEditClearsOtherEdits() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(tokenAddress);

        // Create multiple edits
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(tokenAddress, "Updated Token 1", "UT1", "https://example.com/logo1.png", 9);
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(tokenAddress, "Updated Token 2", "UT2", "https://example.com/logo2.png", 12);

        // Accept first edit
        vm.prank(owner);
        tokenEdits.acceptEdit(tokenAddress, 1);

        // Verify second edit was cleared
        (address submitter, , , , , ) = tokenEdits.editsOnTokens(tokenAddress, 2);
        assertEq(submitter, address(0), "Second edit should be cleared");

        // Verify edit count was reset
        assertEq(tokenEdits.editCount(tokenAddress), 0, "Edit count should be reset");
    }

    function testEditTracking() public {
        // Add and approve a token first
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(tokenAddress);

        // Verify no edits initially
        assertEq(tokenEdits.getTokensWithEditsCount(), 0);

        // Create first edit
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9);

        // Verify token is tracked
        assertEq(tokenEdits.getTokensWithEditsCount(), 1);
        assertEq(tokenEdits.getTokenWithEdits(0), tokenAddress);
        assertEq(tokenEdits.editCount(tokenAddress), 1);

        // Create second edit
        vm.prank(nonOwner2);
        tokenEdits.proposeEdit(tokenAddress, "Updated Token 2", "UTK2", "https://example.com/new_logo2.png", 12);

        // Verify tracking remains correct
        assertEq(tokenEdits.getTokensWithEditsCount(), 1);
        assertEq(tokenEdits.editCount(tokenAddress), 2);
    }

    function testListEdits() public {
        // Add and approve a token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(tokenAddress);

        // Create multiple edits
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(tokenAddress, "Updated Token 1", "UT1", "https://example.com/logo1.png", 9);
        vm.prank(nonOwner2);
        tokenEdits.proposeEdit(tokenAddress, "Updated Token 2", "UT2", "https://example.com/logo2.png", 12);

        // Test listing with pagination
        (TokenEdits.TokenEdit[] memory edits, uint256 finalIndex, bool hasMore) = tokenEdits.listEdits(0, 1);

        assertEq(edits.length, 1);
        assertEq(edits[0].name, "Updated Token 1");
        assertTrue(hasMore);

        // Get second page
        (edits, finalIndex, hasMore) = tokenEdits.listEdits(1, 1);

        assertEq(edits.length, 1);
        assertEq(edits[0].name, "Updated Token 2");
        assertFalse(hasMore);
    }
}
