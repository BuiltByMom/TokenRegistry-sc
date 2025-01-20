// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/TokenEdits.sol";
import "src/TokenRegistry.sol";
import "src/TokentrollerV1.sol";
import "test/MockERC20.sol";
import "src/interfaces/ITokenEdits.sol";

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
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(token), metadata);
        vm.stopPrank();

        vm.startPrank(owner);
        tokenRegistry.approveToken(address(token));
        vm.stopPrank();

        // Now propose an edit
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });
        tokenEdits.proposeEdit(address(token), metadata2);
        vm.stopPrank();

        // Check that the edit is stored
        MetadataInput[][] memory storedEdits = tokenEdits.getTokenEdits(address(token));
        assertEq(storedEdits[0][0].field, "logoURI", "Logo URI field should be stored");
        assertEq(storedEdits[0][0].value, "https://example.com/new_logo.png", "Logo URI value should be stored");
        assertEq(tokenEdits.getEditCount(address(token)), 1, "Edit count should be 1");
    }

    function testCannotProposeEditForNonApprovedToken() public {
        // Add token but don't approve it
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(token), metadata);

        // Try to propose edit for pending token
        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo2.png" });
        vm.expectRevert("Not authorized to propose edit");
        tokenEdits.proposeEdit(address(token), metadata2);
        vm.stopPrank();
    }

    function testAcceptEdit() public {
        // Add and approve token
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(token), metadata);
        vm.stopPrank();

        vm.startPrank(owner);
        tokenRegistry.approveToken(address(token));
        vm.stopPrank();

        // Create edit
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });
        tokenEdits.proposeEdit(address(token), metadata2);
        vm.stopPrank();

        // Accept the edit
        vm.startPrank(owner);
        tokenEdits.acceptEdit(address(token), 1);
        vm.stopPrank();

        // Verify token was updated and edits were cleared
        assertEq(tokenEdits.getEditCount(address(token)), 0, "Edit count should be reset");
        MetadataInput[][] memory storedEdits = tokenEdits.getTokenEdits(address(token));
        assertEq(storedEdits.length, 0, "All edits should be cleared");

        assertEq(tokenRegistry.getToken(address(token)).logoURI, "https://example.com/new_logo.png");
    }

    function testRejectEdit() public {
        // Add and approve token
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(token), metadata);
        vm.stopPrank();

        vm.startPrank(owner);
        tokenRegistry.approveToken(address(token));
        vm.stopPrank();

        // Create edit
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });
        tokenEdits.proposeEdit(address(token), metadata2);
        vm.stopPrank();

        // Reject the edit
        vm.startPrank(owner);
        tokenEdits.rejectEdit(address(token), 1, "Invalid logo");
        vm.stopPrank();

        // Verify edit was cleared
        MetadataInput[][] memory storedEdits = tokenEdits.getTokenEdits(address(token));
        assertEq(storedEdits.length, 0, "Edit should be cleared");
        assertEq(tokenEdits.getEditCount(address(token)), 0, "Edit count should be 0");
    }

    function testRejectMultipleEdits() public {
        // Add and approve token
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(token), metadata);
        vm.stopPrank();

        vm.startPrank(owner);
        tokenRegistry.approveToken(address(token));
        vm.stopPrank();

        // Create edit
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo1.png" });
        tokenEdits.proposeEdit(address(token), metadata2);
        vm.stopPrank();

        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata3 = new MetadataInput[](1);
        metadata3[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo2.png" });
        tokenEdits.proposeEdit(address(token), metadata3);
        vm.stopPrank();

        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata4 = new MetadataInput[](1);
        metadata4[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo3.png" });
        tokenEdits.proposeEdit(address(token), metadata4);
        vm.stopPrank();

        assertEq(tokenEdits.getEditCount(address(token)), 3, "Edit count should be 3");

        // Reject the edit
        vm.startPrank(owner);
        tokenEdits.rejectEdit(address(token), 1, "Invalid logo");
        vm.stopPrank();

        assertEq(tokenEdits.getEditCount(address(token)), 2, "Edit count after rejection should be 2");

        vm.startPrank(owner);
        tokenEdits.rejectEdit(address(token), 2, "Invalid logo");
        tokenEdits.rejectEdit(address(token), 3, "Invalid logo");
        vm.stopPrank();

        // Verify edit was cleared
        MetadataInput[][] memory storedEdits = tokenEdits.getTokenEdits(address(token));
        assertEq(storedEdits.length, 0, "Edit should be cleared");
        assertEq(tokenEdits.getEditCount(address(token)), 0, "Edit count should be 0");
    }

    function testCannotRejectEditWithoutPermission() public {
        // Add and approve token
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(token), metadata);
        vm.stopPrank();

        vm.startPrank(owner);
        tokenRegistry.approveToken(address(token));
        vm.stopPrank();

        // Create edit
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });
        tokenEdits.proposeEdit(address(token), metadata2);
        vm.stopPrank();

        // Try to reject without permission
        vm.startPrank(nonOwner);
        vm.expectRevert("Not authorized to reject edit");
        tokenEdits.rejectEdit(address(token), 1, "Invalid logo");
        vm.stopPrank();
    }

    function testAcceptEditClearsOtherEdits() public {
        // Add and approve token
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(token), metadata);
        vm.stopPrank();

        vm.startPrank(owner);
        tokenRegistry.approveToken(address(token));
        vm.stopPrank();

        // Create multiple edits
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo1.png" });
        tokenEdits.proposeEdit(address(token), metadata2);

        MetadataInput[] memory metadata3 = new MetadataInput[](1);
        metadata3[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo2.png" });
        tokenEdits.proposeEdit(address(token), metadata3);
        vm.stopPrank();

        // Accept first edit
        vm.startPrank(owner);
        tokenEdits.acceptEdit(address(token), 1);
        vm.stopPrank();

        // Verify all edits were cleared
        MetadataInput[][] memory storedEdits = tokenEdits.getTokenEdits(address(token));
        assertEq(storedEdits.length, 0, "All edits should be cleared");
        assertEq(tokenEdits.getEditCount(address(token)), 0, "Edit count should be reset");
    }

    function testAcceptAfterReject() public {
        // Add and approve token
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(token), metadata);
        vm.stopPrank();

        vm.startPrank(owner);
        tokenRegistry.approveToken(address(token));
        vm.stopPrank();

        // Create multiple edits
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo1.png" });
        tokenEdits.proposeEdit(address(token), metadata2);

        MetadataInput[] memory metadata3 = new MetadataInput[](1);
        metadata3[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo2.png" });
        tokenEdits.proposeEdit(address(token), metadata3);
        vm.stopPrank();

        MetadataInput[] memory metadata4 = new MetadataInput[](1);
        metadata4[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo3.png" });
        tokenEdits.proposeEdit(address(token), metadata4);
        vm.stopPrank();

        // Reject first edit
        vm.startPrank(owner);
        tokenEdits.rejectEdit(address(token), 1, "Invalid logo");
        vm.stopPrank();

        // Accept third edit
        vm.startPrank(owner);
        tokenEdits.acceptEdit(address(token), 3);
        vm.stopPrank();

        // Verify all edits were cleared
        MetadataInput[][] memory storedEdits = tokenEdits.getTokenEdits(address(token));
        assertEq(storedEdits.length, 0, "All edits should be cleared");
        assertEq(tokenEdits.getEditCount(address(token)), 0, "Edit count should be reset");
    }

    function testEditTracking() public {
        // Add and approve a token first
        vm.prank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(token), metadata);
        vm.prank(owner);
        tokenRegistry.approveToken(address(token));

        // Verify no edits initially
        assertEq(tokenEdits.getTokensWithEditsCount(), 0);
        assertEq(tokenEdits.getEditCount(address(token)), 0);

        // Create first edit
        vm.prank(nonOwner);
        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });
        tokenEdits.proposeEdit(address(token), metadata2);

        // Verify token is tracked
        assertEq(tokenEdits.getTokensWithEditsCount(), 1);
        assertEq(tokenEdits.getTokenEdits(address(token))[0][0].value, "https://example.com/new_logo.png");
        assertEq(tokenEdits.getEditCount(address(token)), 1);

        // Create second edit
        vm.prank(nonOwner2);
        MetadataInput[] memory metadata3 = new MetadataInput[](1);
        metadata3[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo2.png" });
        tokenEdits.proposeEdit(address(token), metadata3);

        // Verify tracking remains correct
        assertEq(tokenEdits.getTokensWithEditsCount(), 1);
        assertEq(tokenEdits.getEditCount(address(token)), 2);
    }

    function testListEdits() public {
        // Add and approve a token
        vm.prank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(token), metadata);
        vm.prank(owner);
        tokenRegistry.approveToken(address(token));

        // Create multiple edits
        vm.prank(nonOwner);
        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo1.png" });
        tokenEdits.proposeEdit(address(token), metadata2);

        vm.prank(nonOwner2);
        MetadataInput[] memory metadata3 = new MetadataInput[](1);
        metadata3[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo2.png" });
        tokenEdits.proposeEdit(address(token), metadata3);

        // Test listing with pagination
        (ITokenEdits.TokenEdit[] memory edits, uint256 total) = tokenEdits.listEdits(0, 1);

        // Verify basic structure
        assertEq(edits.length, 1);
        assertEq(edits[0].updates.length, 2); // Should have both edits
        assertEq(total, 1); // One token with edits

        // Verify edit contents in chronological order
        assertEq(edits[0].updates[0][0].field, "logoURI");
        assertEq(edits[0].updates[0][0].value, "https://example.com/logo1.png"); // First edit
        assertEq(edits[0].updates[1][0].field, "logoURI");
        assertEq(edits[0].updates[1][0].value, "https://example.com/logo2.png"); // Second edit

        // Get second page (should be empty)
        (ITokenEdits.TokenEdit[] memory edits2, uint256 total2) = tokenEdits.listEdits(1, 1);
        assertEq(edits2.length, 0);
        assertEq(total2, 1);
    }
}
