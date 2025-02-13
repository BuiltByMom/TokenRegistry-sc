// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/Helper.sol";
import "src/TokenRegistry.sol";
import "src/TokenEdits.sol";
import "src/TokenMetadata.sol";
import "src/controllers/TokentrollerV1.sol";
import "./mocks/MockERC20.sol";

contract HelperTest is Test {
    Helper helper;
    TokenRegistry tokenRegistry;
    TokenEdits tokenEdits;
    TokenMetadata tokenMetadata;
    TokentrollerV1 tokentroller;
    address owner = address(1);
    address nonOwner = address(2);
    address nonOwner2 = address(3);
    MockERC20 mockToken;
    MockERC20 mockToken2;
    MockERC20 mockToken3;

    function setUp() public {
        // Deploy tokentroller first - it will deploy all other contracts
        tokentroller = new TokentrollerV1(owner);
        // Get the deployed contract addresses
        tokenRegistry = TokenRegistry(tokentroller.tokenRegistry());
        tokenEdits = TokenEdits(tokentroller.tokenEdits());
        tokenMetadata = TokenMetadata(tokentroller.tokenMetadata());

        // Deploy helper
        helper = new Helper(address(tokenRegistry), address(tokenEdits), address(tokenMetadata), address(tokentroller));

        // Add helper as a trusted helper
        vm.prank(owner);
        tokentroller.addTrustedHelper(address(helper));

        // Deploy mock tokens
        mockToken = new MockERC20("Test Token", "TEST", 18);
        mockToken2 = new MockERC20("Test Token 2", "TEST2", 18);
        mockToken3 = new MockERC20("Test Token 3", "TEST3", 18);
    }

    function testAddAndApproveToken() public {
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.prank(owner);
        helper.addAndApproveToken(address(mockToken), metadata);

        // Verify token is approved
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken))), uint8(TokenStatus.APPROVED));
        assertEq(tokenRegistry.getToken(address(mockToken)).logoURI, "https://example.com/logo.png");
    }

    function testProposeAndApproveEdit() public {
        // First add and approve a token
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.prank(owner);
        helper.addAndApproveToken(address(mockToken), metadata);

        // Now propose and approve an edit
        MetadataInput[] memory newMetadata = new MetadataInput[](1);
        newMetadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });

        vm.prank(owner);
        helper.proposeAndApproveEdit(address(mockToken), newMetadata);

        // Verify edit was applied
        assertEq(tokenRegistry.getToken(address(mockToken)).logoURI, "https://example.com/new_logo.png");
    }

    function testBatchApproveTokens() public {
        // Add multiple tokens first
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.startPrank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata);
        tokenRegistry.addToken(address(mockToken2), metadata);
        tokenRegistry.addToken(address(mockToken3), metadata);
        vm.stopPrank();

        // Batch approve tokens
        address[] memory tokens = new address[](3);
        tokens[0] = address(mockToken);
        tokens[1] = address(mockToken2);
        tokens[2] = address(mockToken3);

        vm.prank(owner);
        helper.batchApproveTokens(tokens);

        // Verify all tokens are approved
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken))), uint8(TokenStatus.APPROVED));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken2))), uint8(TokenStatus.APPROVED));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken3))), uint8(TokenStatus.APPROVED));
    }

    function testBatchRejectTokens() public {
        // Add multiple tokens first
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.startPrank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata);
        tokenRegistry.addToken(address(mockToken2), metadata);
        tokenRegistry.addToken(address(mockToken3), metadata);
        vm.stopPrank();

        // Batch reject tokens
        address[] memory tokens = new address[](3);
        tokens[0] = address(mockToken);
        tokens[1] = address(mockToken2);
        tokens[2] = address(mockToken3);

        vm.prank(owner);
        helper.batchRejectTokens(tokens, "Test rejection");

        // Verify all tokens are rejected
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken))), uint8(TokenStatus.REJECTED));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken2))), uint8(TokenStatus.REJECTED));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken3))), uint8(TokenStatus.REJECTED));
    }

    function testBatchAcceptEdits() public {
        // First add and approve a token
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.startPrank(owner);
        helper.addAndApproveToken(address(mockToken), metadata);
        helper.addAndApproveToken(address(mockToken2), metadata);
        vm.stopPrank();

        // Create edits for both tokens
        vm.startPrank(nonOwner);
        MetadataInput[] memory newMetadata1 = new MetadataInput[](1);
        newMetadata1[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo1.png" });
        uint256 editId1 = tokenEdits.proposeEdit(address(mockToken), newMetadata1);

        MetadataInput[] memory newMetadata2 = new MetadataInput[](1);
        newMetadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo2.png" });
        uint256 editId2 = tokenEdits.proposeEdit(address(mockToken2), newMetadata2);
        vm.stopPrank();

        // Batch accept edits
        Helper.BatchEdits[] memory edits = new Helper.BatchEdits[](2);
        edits[0] = Helper.BatchEdits({ contractAddress: address(mockToken), editId: editId1 });
        edits[1] = Helper.BatchEdits({ contractAddress: address(mockToken2), editId: editId2 });

        vm.prank(owner);
        helper.batchAcceptEdits(edits);

        // Verify edits were applied
        assertEq(tokenRegistry.getToken(address(mockToken)).logoURI, "https://example.com/new_logo1.png");
        assertEq(tokenRegistry.getToken(address(mockToken2)).logoURI, "https://example.com/new_logo2.png");
    }

    function testBatchRejectEdits() public {
        // First add and approve tokens
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.startPrank(owner);
        helper.addAndApproveToken(address(mockToken), metadata);
        helper.addAndApproveToken(address(mockToken2), metadata);
        vm.stopPrank();

        // Create edits for both tokens
        vm.startPrank(nonOwner);
        MetadataInput[] memory newMetadata1 = new MetadataInput[](1);
        newMetadata1[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo1.png" });
        uint256 editId1 = tokenEdits.proposeEdit(address(mockToken), newMetadata1);

        MetadataInput[] memory newMetadata2 = new MetadataInput[](1);
        newMetadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo2.png" });
        uint256 editId2 = tokenEdits.proposeEdit(address(mockToken2), newMetadata2);
        vm.stopPrank();

        // Batch reject edits
        Helper.BatchEdits[] memory edits = new Helper.BatchEdits[](2);
        edits[0] = Helper.BatchEdits({ contractAddress: address(mockToken), editId: editId1 });
        edits[1] = Helper.BatchEdits({ contractAddress: address(mockToken2), editId: editId2 });

        vm.prank(owner);
        helper.batchRejectEdits(edits, "Test rejection");

        // Verify original metadata remains unchanged
        assertEq(tokenRegistry.getToken(address(mockToken)).logoURI, "https://example.com/logo.png");
        assertEq(tokenRegistry.getToken(address(mockToken2)).logoURI, "https://example.com/logo.png");
    }

    function testBatchApproveAndAcceptEdits() public {
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        // First set: Add tokens that will be approved in batch
        vm.startPrank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata);
        tokenRegistry.addToken(address(mockToken2), metadata);
        vm.stopPrank();

        // Second set: Add and approve tokens that will receive edits
        vm.prank(owner);
        helper.addAndApproveToken(address(mockToken3), metadata);

        // Create edits for the approved token
        vm.startPrank(nonOwner);
        MetadataInput[] memory newMetadata = new MetadataInput[](1);
        newMetadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });
        uint256 editId = tokenEdits.proposeEdit(address(mockToken3), newMetadata);
        vm.stopPrank();

        // Batch approve pending tokens and accept edits for different tokens
        address[] memory tokensToApprove = new address[](2);
        tokensToApprove[0] = address(mockToken);
        tokensToApprove[1] = address(mockToken2);

        Helper.BatchEdits[] memory editsToAccept = new Helper.BatchEdits[](1);
        editsToAccept[0] = Helper.BatchEdits({ contractAddress: address(mockToken3), editId: editId });

        vm.prank(owner);
        helper.batchApproveAndAcceptEdits(tokensToApprove, editsToAccept);

        // Verify tokens were approved
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken))), uint8(TokenStatus.APPROVED));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken2))), uint8(TokenStatus.APPROVED));

        // Verify edit was applied to the different token
        assertEq(tokenRegistry.getToken(address(mockToken3)).logoURI, "https://example.com/new_logo.png");
    }

    function testBatchRejectAndRejectEdits() public {
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        // First set: Add tokens that will be rejected in batch
        vm.startPrank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata);
        tokenRegistry.addToken(address(mockToken2), metadata);
        vm.stopPrank();

        // Second set: Add and approve token that will receive edit
        vm.prank(owner);
        helper.addAndApproveToken(address(mockToken3), metadata);

        // Create edit for the approved token
        vm.startPrank(nonOwner);
        MetadataInput[] memory newMetadata = new MetadataInput[](1);
        newMetadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });
        uint256 editId = tokenEdits.proposeEdit(address(mockToken3), newMetadata);
        vm.stopPrank();

        // Batch reject pending tokens and reject edits for different tokens
        address[] memory tokensToReject = new address[](2);
        tokensToReject[0] = address(mockToken);
        tokensToReject[1] = address(mockToken2);

        Helper.BatchEdits[] memory editsToReject = new Helper.BatchEdits[](1);
        editsToReject[0] = Helper.BatchEdits({ contractAddress: address(mockToken3), editId: editId });

        vm.prank(owner);
        helper.batchRejectAndRejectEdits(tokensToReject, editsToReject, "Test rejection");

        // Verify tokens were rejected
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken))), uint8(TokenStatus.REJECTED));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken2))), uint8(TokenStatus.REJECTED));

        // Verify original metadata remains unchanged for the edited token
        assertEq(tokenRegistry.getToken(address(mockToken3)).logoURI, "https://example.com/logo.png");
    }

    function testUnauthorizedAddAndApprove() public {
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.startPrank(nonOwner);
        vm.expectRevert("Not authorized to approve token");
        helper.addAndApproveToken(address(mockToken), metadata);
        vm.stopPrank();
    }

    function testUnauthorizedProposeAndApproveEdit() public {
        // First add and approve a token as owner
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.prank(owner);
        helper.addAndApproveToken(address(mockToken), metadata);

        // Try to propose and approve edit as non-owner
        MetadataInput[] memory newMetadata = new MetadataInput[](1);
        newMetadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });

        vm.startPrank(nonOwner);
        vm.expectRevert("Not authorized to accept edit");
        helper.proposeAndApproveEdit(address(mockToken), newMetadata);
        vm.stopPrank();
    }

    function testUnauthorizedBatchApprove() public {
        // Add tokens first
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.startPrank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata);
        tokenRegistry.addToken(address(mockToken2), metadata);
        vm.stopPrank();

        // Try to batch approve as non-owner
        address[] memory tokens = new address[](2);
        tokens[0] = address(mockToken);
        tokens[1] = address(mockToken2);

        vm.startPrank(nonOwner);
        vm.expectRevert("Not authorized to approve token");
        helper.batchApproveTokens(tokens);
        vm.stopPrank();
    }

    function testUnauthorizedBatchReject() public {
        // Add tokens first
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.startPrank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata);
        tokenRegistry.addToken(address(mockToken2), metadata);
        vm.stopPrank();

        // Try to batch reject as non-owner
        address[] memory tokens = new address[](2);
        tokens[0] = address(mockToken);
        tokens[1] = address(mockToken2);

        vm.startPrank(nonOwner);
        vm.expectRevert("Not authorized to reject token");
        helper.batchRejectTokens(tokens, "Test rejection");
        vm.stopPrank();
    }

    function testUnauthorizedBatchApproveAndAcceptEdits() public {
        // First set: Add tokens that will be approved
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.startPrank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata);
        tokenRegistry.addToken(address(mockToken2), metadata);
        vm.stopPrank();

        // Second set: Add and approve token that will receive edit
        vm.prank(owner);
        helper.addAndApproveToken(address(mockToken3), metadata);

        // Create edit for the approved token
        vm.startPrank(nonOwner);
        MetadataInput[] memory newMetadata = new MetadataInput[](1);
        newMetadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });
        uint256 editId = tokenEdits.proposeEdit(address(mockToken3), newMetadata);
        vm.stopPrank();

        // Try to batch approve and accept as non-owner
        address[] memory tokensToApprove = new address[](2);
        tokensToApprove[0] = address(mockToken);
        tokensToApprove[1] = address(mockToken2);

        Helper.BatchEdits[] memory editsToAccept = new Helper.BatchEdits[](1);
        editsToAccept[0] = Helper.BatchEdits({ contractAddress: address(mockToken3), editId: editId });

        vm.startPrank(nonOwner);
        vm.expectRevert("Not authorized to accept edit");
        helper.batchApproveAndAcceptEdits(tokensToApprove, editsToAccept);
        vm.stopPrank();
    }

    function testUnauthorizedBatchRejectAndRejectEdits() public {
        // First set: Add tokens that will be rejected
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.startPrank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata);
        tokenRegistry.addToken(address(mockToken2), metadata);
        vm.stopPrank();

        // Second set: Add and approve token that will receive edit
        vm.prank(owner);
        helper.addAndApproveToken(address(mockToken3), metadata);

        // Create edit for the approved token
        vm.startPrank(nonOwner);
        MetadataInput[] memory newMetadata = new MetadataInput[](1);
        newMetadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });
        uint256 editId = tokenEdits.proposeEdit(address(mockToken3), newMetadata);
        vm.stopPrank();

        // Try to batch reject and reject edits as non-owner
        address[] memory tokensToReject = new address[](2);
        tokensToReject[0] = address(mockToken);
        tokensToReject[1] = address(mockToken2);

        Helper.BatchEdits[] memory editsToReject = new Helper.BatchEdits[](1);
        editsToReject[0] = Helper.BatchEdits({ contractAddress: address(mockToken3), editId: editId });

        vm.startPrank(nonOwner);
        vm.expectRevert("Not authorized to reject edit");
        helper.batchRejectAndRejectEdits(tokensToReject, editsToReject, "Test rejection");
        vm.stopPrank();
    }
}
