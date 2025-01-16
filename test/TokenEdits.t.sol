// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/TokenEdits.sol";
import "src/TokenRegistry.sol";
import "src/TokentrollerV1.sol";
import "src/interfaces/ITokenRegistry.sol";
import "test/MockERC20.sol";

contract TokenEditsTest is Test {
    TokenEdits tokenEdits;
    TokenRegistry tokenRegistry;
    TokentrollerV1 tokentroller;
    address owner = address(1);
    address nonOwner = address(2);
    address nonOwner2 = address(3);
    MockERC20 token;

    function setUp() public {
        // Deploy tokentroller first - it will deploy all other contracts
        tokentroller = new TokentrollerV1(owner);
        // Get the deployed contract addresses
        tokenRegistry = TokenRegistry(tokentroller.tokenRegistry());
        tokenEdits = TokenEdits(tokentroller.tokenEdits());
        // Deploy mock token
        token = new MockERC20("Test Token", "TEST", 18);
    }

    function testProposeEdit() public {
        // First add and approve a token
        vm.prank(nonOwner);
        console.log("Adding token from address:", nonOwner);
        tokenRegistry.addToken(address(token), "https://example.com/logo.png");

        vm.prank(owner);
        console.log("Approving token from owner:", owner);
        tokenRegistry.approveToken(address(token));

        // Now propose an edit
        vm.prank(nonOwner);
        console.log("Proposing edit from address:", nonOwner);
        console.log("Token status:", uint(TokenRegistry(tokenRegistry).tokenStatus(address(token))));
        tokenEdits.proposeEdit(address(token), "https://example.com/new_logo.png");

        // Check that the edit is stored
        assertEq(tokenEdits.edits(address(token), 1), "https://example.com/new_logo.png", "Logo URI should be stored");
        assertEq(tokenEdits.getEditCount(address(token)), 1, "Edit count should be 1");
    }

    function testCannotProposeEditForNonApprovedToken() public {
        // Add token but don't approve it
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(token), "https://example.com/logo.png");

        // Try to propose edit for pending token
        vm.prank(nonOwner);
        vm.expectRevert("Not authorized to propose edit");
        tokenEdits.proposeEdit(address(token), "https://example.com/new_logo.png");
    }

    function testAcceptEdit() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(token), "https://example.com/logo.png");
        vm.prank(owner);
        tokenRegistry.approveToken(address(token));

        // Create edit
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(address(token), "https://example.com/new_logo.png");

        // Accept the edit
        vm.prank(owner);
        tokenEdits.acceptEdit(address(token), 1);

        // Verify token was updated and edits were cleared
        assertEq(tokenEdits.getEditCount(address(token)), 0, "Edit count should be reset");
        assertEq(tokenEdits.edits(address(token), 1), "", "Edit should be cleared");
    }

    function testRejectEdit() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(token), "https://example.com/logo.png");
        vm.prank(owner);
        tokenRegistry.approveToken(address(token));

        // Create edit
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(address(token), "https://example.com/new_logo.png");

        // Reject the edit
        vm.prank(owner);
        tokenEdits.rejectEdit(address(token), 1, "Invalid logo");

        // Verify edit was cleared
        assertEq(tokenEdits.edits(address(token), 1), "", "Edit should be cleared");
        assertEq(tokenEdits.getEditCount(address(token)), 0, "Edit count should be 0");
    }

    function testCannotRejectEditWithoutPermission() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(token), "https://example.com/logo.png");
        vm.prank(owner);
        tokenRegistry.approveToken(address(token));

        // Create edit
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(address(token), "https://example.com/new_logo.png");

        // Try to reject without permission
        vm.prank(nonOwner);
        vm.expectRevert("Not authorized to reject edit");
        tokenEdits.rejectEdit(address(token), 1, "Invalid logo");
    }

    function testAcceptEditClearsOtherEdits() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(token), "https://example.com/logo.png");
        vm.prank(owner);
        tokenRegistry.approveToken(address(token));

        // Create multiple edits
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(address(token), "https://example.com/logo1.png");
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(address(token), "https://example.com/logo2.png");

        // Accept first edit
        vm.prank(owner);
        tokenEdits.acceptEdit(address(token), 1);

        // Verify all edits were cleared
        assertEq(tokenEdits.edits(address(token), 1), "", "First edit should be cleared");
        assertEq(tokenEdits.edits(address(token), 2), "", "Second edit should be cleared");
        assertEq(tokenEdits.getEditCount(address(token)), 0, "Edit count should be reset");
    }

    function testEditTracking() public {
        // Add and approve a token first
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(token), "https://example.com/logo.png");
        vm.prank(owner);
        tokenRegistry.approveToken(address(token));

        // Verify no edits initially
        assertEq(tokenEdits.getTokensWithEditsCount(), 0);
        assertEq(tokenEdits.getEditCount(address(token)), 0);

        // Create first edit
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(address(token), "https://example.com/new_logo.png");

        // Verify token is tracked
        assertEq(tokenEdits.getTokensWithEditsCount(), 1);
        assertEq(tokenEdits.getTokenEdits(address(token))[0], "https://example.com/new_logo.png");
        assertEq(tokenEdits.getEditCount(address(token)), 1);

        // Create second edit
        vm.prank(nonOwner2);
        tokenEdits.proposeEdit(address(token), "https://example.com/new_logo2.png");

        // Verify tracking remains correct
        assertEq(tokenEdits.getTokensWithEditsCount(), 1);
        assertEq(tokenEdits.getEditCount(address(token)), 2);
    }

    function testListEdits() public {
        // Add and approve a token
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(token), "https://example.com/logo.png");
        vm.prank(owner);
        tokenRegistry.approveToken(address(token));

        // Create multiple edits
        vm.prank(nonOwner);
        tokenEdits.proposeEdit(address(token), "https://example.com/logo1.png");
        vm.prank(nonOwner2);
        tokenEdits.proposeEdit(address(token), "https://example.com/logo2.png");

        // Test listing with pagination
        (string[] memory logoURIs, uint256 total) = tokenEdits.listEdits(0, 1);

        assertEq(logoURIs.length, 1);
        assertEq(logoURIs[0], "https://example.com/logo2.png"); // Latest edit
        assertEq(total, 1); // One token with edits

        // Get second page (should be empty)
        (logoURIs, total) = tokenEdits.listEdits(1, 1);
        assertEq(logoURIs.length, 0);
        assertEq(total, 1);
    }
}
