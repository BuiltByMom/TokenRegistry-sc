// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
        (Helper.BatchResult[] memory results, uint256[3] memory summary) = helper.batchApproveTokens(tokens);

        // Verify summary
        assertEq(summary[0], 3, "Total operations should be 3");
        assertEq(summary[1], 3, "Successful operations should be 3");
        assertEq(summary[2], 0, "Failed operations should be 0");

        // Verify results
        for (uint i = 0; i < results.length; i++) {
            assertTrue(results[i].success, "Operation should succeed");
            assertEq(results[i].token, tokens[i], "Token address should match");
            assertEq(results[i].errorMessage, "", "Error message should be empty");
        }

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
        (Helper.BatchResult[] memory results, uint256[3] memory summary) = helper.batchRejectTokens(
            tokens,
            "Test rejection"
        );

        // Verify summary
        assertEq(summary[0], 3, "Total operations should be 3");
        assertEq(summary[1], 3, "Successful operations should be 3");
        assertEq(summary[2], 0, "Failed operations should be 0");

        // Verify results
        for (uint i = 0; i < results.length; i++) {
            assertTrue(results[i].success, "Operation should succeed");
            assertEq(results[i].token, tokens[i], "Token address should match");
            assertEq(results[i].errorMessage, "", "Error message should be empty");
        }

        // Verify all tokens are rejected
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken))), uint8(TokenStatus.REJECTED));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken2))), uint8(TokenStatus.REJECTED));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken3))), uint8(TokenStatus.REJECTED));
    }

    function testBatchAddAndApproveTokens() public {
        // Create metadata for tokens
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        // Create batch input with 3 tokens - 2 valid and 1 invalid
        Helper.BatchTokenInput[] memory tokens = new Helper.BatchTokenInput[](3);
        tokens[0] = Helper.BatchTokenInput({ contractAddress: address(mockToken), metadata: metadata });
        tokens[1] = Helper.BatchTokenInput({
            contractAddress: address(0), // Invalid address
            metadata: metadata
        });
        tokens[2] = Helper.BatchTokenInput({ contractAddress: address(mockToken2), metadata: metadata });

        // Execute batch operation as owner
        vm.prank(owner);
        (Helper.BatchResult[] memory results, uint256[3] memory summary) = helper.batchAddAndApproveTokens(tokens);

        // Verify summary shows partial success
        assertEq(summary[0], 3, "Total operations should be 3");
        assertEq(summary[1], 2, "Successful operations should be 2");
        assertEq(summary[2], 1, "Failed operations should be 1");

        // Verify results
        assertTrue(results[0].success, "First token operation should succeed");
        assertFalse(results[1].success, "Second token operation should fail");
        assertTrue(results[2].success, "Third token operation should succeed");
        assertEq(results[1].errorMessage, "Invalid token address", "Should have invalid address error");

        // Verify final states
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken))), uint8(TokenStatus.APPROVED));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken2))), uint8(TokenStatus.APPROVED));
    }

    function testUnauthorizedBatchAddAndApproveTokens() public {
        // Create metadata for tokens
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        // Create batch input with 2 valid tokens
        Helper.BatchTokenInput[] memory tokens = new Helper.BatchTokenInput[](2);
        tokens[0] = Helper.BatchTokenInput({ contractAddress: address(mockToken), metadata: metadata });
        tokens[1] = Helper.BatchTokenInput({ contractAddress: address(mockToken2), metadata: metadata });

        // Try to batch add and approve as non-owner
        vm.prank(nonOwner);
        (Helper.BatchResult[] memory results, uint256[3] memory summary) = helper.batchAddAndApproveTokens(tokens);

        // Verify summary shows failures
        assertEq(summary[0], 2, "Total operations should be 2");
        assertEq(summary[1], 0, "Successful operations should be 0");
        assertEq(summary[2], 2, "Failed operations should be 2");

        // Verify results show unauthorized errors
        for (uint i = 0; i < results.length; i++) {
            assertFalse(results[i].success, "Operation should fail");
            assertEq(results[i].token, tokens[i].contractAddress, "Token address should match");
            assertEq(results[i].errorMessage, "Not authorized to approve token", "Should have authorization error");
        }

        // Verify tokens were not added
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken))), uint8(TokenStatus.NONE));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken2))), uint8(TokenStatus.NONE));
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
        (Helper.BatchResult[] memory results, uint256[3] memory summary) = helper.batchAcceptEdits(edits);

        // Verify summary
        assertEq(summary[0], 2, "Total operations should be 2");
        assertEq(summary[1], 2, "Successful operations should be 2");
        assertEq(summary[2], 0, "Failed operations should be 0");

        // Verify results
        for (uint i = 0; i < results.length; i++) {
            assertTrue(results[i].success, "Operation should succeed");
            assertEq(results[i].token, edits[i].contractAddress, "Token address should match");
            assertEq(results[i].editId, edits[i].editId, "Edit ID should match");
            assertEq(results[i].errorMessage, "", "Error message should be empty");
        }

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
        (Helper.BatchResult[] memory results, uint256[3] memory summary) = helper.batchRejectEdits(
            edits,
            "Test rejection"
        );

        // Verify summary
        assertEq(summary[0], 2, "Total operations should be 2");
        assertEq(summary[1], 2, "Successful operations should be 2");
        assertEq(summary[2], 0, "Failed operations should be 0");

        // Verify results
        for (uint i = 0; i < results.length; i++) {
            assertTrue(results[i].success, "Operation should succeed");
            assertEq(results[i].token, edits[i].contractAddress, "Token address should match");
            assertEq(results[i].editId, edits[i].editId, "Edit ID should match");
            assertEq(results[i].errorMessage, "", "Error message should be empty");
        }

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
        (
            Helper.BatchResult[] memory tokenResults,
            Helper.BatchResult[] memory editResults,
            uint256[3] memory tokenSummary,
            uint256[3] memory editSummary
        ) = helper.batchApproveAndAcceptEdits(tokensToApprove, editsToAccept);

        // Verify token summary
        assertEq(tokenSummary[0], 2, "Total token operations should be 2");
        assertEq(tokenSummary[1], 2, "Successful token operations should be 2");
        assertEq(tokenSummary[2], 0, "Failed token operations should be 0");

        // Verify edit summary
        assertEq(editSummary[0], 1, "Total edit operations should be 1");
        assertEq(editSummary[1], 1, "Successful edit operations should be 1");
        assertEq(editSummary[2], 0, "Failed edit operations should be 0");

        // Verify token results
        for (uint i = 0; i < tokenResults.length; i++) {
            assertTrue(tokenResults[i].success, "Token operation should succeed");
            assertEq(tokenResults[i].token, tokensToApprove[i], "Token address should match");
            assertEq(tokenResults[i].errorMessage, "", "Error message should be empty");
        }

        // Verify edit results
        assertTrue(editResults[0].success, "Edit operation should succeed");
        assertEq(editResults[0].token, editsToAccept[0].contractAddress, "Token address should match");
        assertEq(editResults[0].editId, editsToAccept[0].editId, "Edit ID should match");
        assertEq(editResults[0].errorMessage, "", "Error message should be empty");

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
        (
            Helper.BatchResult[] memory tokenResults,
            Helper.BatchResult[] memory editResults,
            uint256[3] memory tokenSummary,
            uint256[3] memory editSummary
        ) = helper.batchRejectAndRejectEdits(tokensToReject, editsToReject, "Test rejection");

        // Verify token summary
        assertEq(tokenSummary[0], 2, "Total token operations should be 2");
        assertEq(tokenSummary[1], 2, "Successful token operations should be 2");
        assertEq(tokenSummary[2], 0, "Failed token operations should be 0");

        // Verify edit summary
        assertEq(editSummary[0], 1, "Total edit operations should be 1");
        assertEq(editSummary[1], 1, "Successful edit operations should be 1");
        assertEq(editSummary[2], 0, "Failed edit operations should be 0");

        // Verify token results
        for (uint i = 0; i < tokenResults.length; i++) {
            assertTrue(tokenResults[i].success, "Token operation should succeed");
            assertEq(tokenResults[i].token, tokensToReject[i], "Token address should match");
            assertEq(tokenResults[i].errorMessage, "", "Error message should be empty");
        }

        // Verify edit results
        assertTrue(editResults[0].success, "Edit operation should succeed");
        assertEq(editResults[0].token, editsToReject[0].contractAddress, "Token address should match");
        assertEq(editResults[0].editId, editsToReject[0].editId, "Edit ID should match");
        assertEq(editResults[0].errorMessage, "", "Error message should be empty");

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

        vm.prank(nonOwner);
        (Helper.BatchResult[] memory results, uint256[3] memory summary) = helper.batchApproveTokens(tokens);

        // Verify summary shows failures
        assertEq(summary[0], 2, "Total operations should be 2");
        assertEq(summary[1], 0, "Successful operations should be 0");
        assertEq(summary[2], 2, "Failed operations should be 2");

        // Verify results show unauthorized errors
        for (uint i = 0; i < results.length; i++) {
            assertFalse(results[i].success, "Operation should fail");
            assertEq(results[i].token, tokens[i], "Token address should match");
            assertEq(results[i].errorMessage, "Not authorized to approve token", "Should have authorization error");
        }

        // Verify tokens remain pending
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken))), uint8(TokenStatus.PENDING));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken2))), uint8(TokenStatus.PENDING));
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

        vm.prank(nonOwner);
        (Helper.BatchResult[] memory results, uint256[3] memory summary) = helper.batchRejectTokens(
            tokens,
            "Test rejection"
        );

        // Verify summary shows failures
        assertEq(summary[0], 2, "Total operations should be 2");
        assertEq(summary[1], 0, "Successful operations should be 0");
        assertEq(summary[2], 2, "Failed operations should be 2");

        // Verify results show unauthorized errors
        for (uint i = 0; i < results.length; i++) {
            assertFalse(results[i].success, "Operation should fail");
            assertEq(results[i].token, tokens[i], "Token address should match");
            assertEq(results[i].errorMessage, "Not authorized to reject token", "Should have authorization error");
        }

        // Verify tokens remain pending
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken))), uint8(TokenStatus.PENDING));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken2))), uint8(TokenStatus.PENDING));
    }

    function testUnauthorizedBatchAcceptEdits() public {
        // First add and approve tokens
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.prank(owner);
        helper.addAndApproveToken(address(mockToken), metadata);

        // Create edit
        vm.startPrank(nonOwner);
        MetadataInput[] memory newMetadata = new MetadataInput[](1);
        newMetadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });
        uint256 editId = tokenEdits.proposeEdit(address(mockToken), newMetadata);
        vm.stopPrank();

        // Try to batch accept edit as non-owner
        Helper.BatchEdits[] memory edits = new Helper.BatchEdits[](1);
        edits[0] = Helper.BatchEdits({ contractAddress: address(mockToken), editId: editId });

        vm.prank(nonOwner);
        (Helper.BatchResult[] memory results, uint256[3] memory summary) = helper.batchAcceptEdits(edits);

        // Verify summary shows failures
        assertEq(summary[0], 1, "Total operations should be 1");
        assertEq(summary[1], 0, "Successful operations should be 0");
        assertEq(summary[2], 1, "Failed operations should be 1");

        // Verify results show unauthorized errors
        assertTrue(!results[0].success, "Operation should fail");
        assertEq(results[0].token, edits[0].contractAddress, "Token address should match");
        assertEq(results[0].editId, edits[0].editId, "Edit ID should match");
        assertEq(results[0].errorMessage, "Not authorized to accept edit", "Should have authorization error");

        // Verify original metadata remains unchanged
        assertEq(tokenRegistry.getToken(address(mockToken)).logoURI, "https://example.com/logo.png");
    }

    function testUnauthorizedBatchRejectEdits() public {
        // First add and approve tokens
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        vm.prank(owner);
        helper.addAndApproveToken(address(mockToken), metadata);

        // Create edit
        vm.startPrank(nonOwner);
        MetadataInput[] memory newMetadata = new MetadataInput[](1);
        newMetadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });
        uint256 editId = tokenEdits.proposeEdit(address(mockToken), newMetadata);
        vm.stopPrank();

        // Try to batch reject edit as non-owner
        Helper.BatchEdits[] memory edits = new Helper.BatchEdits[](1);
        edits[0] = Helper.BatchEdits({ contractAddress: address(mockToken), editId: editId });

        vm.prank(nonOwner);
        (Helper.BatchResult[] memory results, uint256[3] memory summary) = helper.batchRejectEdits(
            edits,
            "Test rejection"
        );

        // Verify summary shows failures
        assertEq(summary[0], 1, "Total operations should be 1");
        assertEq(summary[1], 0, "Successful operations should be 0");
        assertEq(summary[2], 1, "Failed operations should be 1");

        // Verify results show unauthorized errors
        assertTrue(!results[0].success, "Operation should fail");
        assertEq(results[0].token, edits[0].contractAddress, "Token address should match");
        assertEq(results[0].editId, edits[0].editId, "Edit ID should match");
        assertEq(results[0].errorMessage, "Not authorized to reject edit", "Should have authorization error");

        // Verify original metadata remains unchanged
        assertEq(tokenRegistry.getToken(address(mockToken)).logoURI, "https://example.com/logo.png");
    }

    function testUnauthorizedBatchApproveAndAcceptEdits() public {
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        // Add pending tokens and create edits
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata);

        vm.prank(owner);
        helper.addAndApproveToken(address(mockToken2), metadata);

        MetadataInput[] memory newMetadata = new MetadataInput[](1);
        newMetadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });
        uint256 editId = tokenEdits.proposeEdit(address(mockToken2), newMetadata);

        // Try to batch approve and accept as non-owner
        address[] memory tokensToApprove = new address[](1);
        tokensToApprove[0] = address(mockToken);

        Helper.BatchEdits[] memory editsToAccept = new Helper.BatchEdits[](1);
        editsToAccept[0] = Helper.BatchEdits({ contractAddress: address(mockToken2), editId: editId });

        vm.prank(nonOwner);
        (
            Helper.BatchResult[] memory tokenResults,
            Helper.BatchResult[] memory editResults,
            uint256[3] memory tokenSummary,
            uint256[3] memory editSummary
        ) = helper.batchApproveAndAcceptEdits(tokensToApprove, editsToAccept);

        // Verify token summary shows failures
        assertEq(tokenSummary[0], 1, "Total token operations should be 1");
        assertEq(tokenSummary[1], 0, "Successful token operations should be 0");
        assertEq(tokenSummary[2], 1, "Failed token operations should be 1");

        // Verify edit summary shows failures
        assertEq(editSummary[0], 1, "Total edit operations should be 1");
        assertEq(editSummary[1], 0, "Successful edit operations should be 0");
        assertEq(editSummary[2], 1, "Failed edit operations should be 1");

        // Verify token results show unauthorized errors
        assertTrue(!tokenResults[0].success, "Token operation should fail");
        assertEq(tokenResults[0].token, tokensToApprove[0], "Token address should match");
        assertEq(tokenResults[0].errorMessage, "Not authorized to approve token", "Should have authorization error");

        // Verify edit results show unauthorized errors
        assertTrue(!editResults[0].success, "Edit operation should fail");
        assertEq(editResults[0].token, editsToAccept[0].contractAddress, "Token address should match");
        assertEq(editResults[0].editId, editsToAccept[0].editId, "Edit ID should match");
        assertEq(editResults[0].errorMessage, "Not authorized to accept edit", "Should have authorization error");

        // Verify states remain unchanged
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken))), uint8(TokenStatus.PENDING));
        assertEq(tokenRegistry.getToken(address(mockToken2)).logoURI, "https://example.com/logo.png");
    }

    function testUnauthorizedBatchRejectAndRejectEdits() public {
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

        // Try to batch reject as non-owner
        address[] memory tokensToReject = new address[](2);
        tokensToReject[0] = address(mockToken);
        tokensToReject[1] = address(mockToken2);

        Helper.BatchEdits[] memory editsToReject = new Helper.BatchEdits[](1);
        editsToReject[0] = Helper.BatchEdits({ contractAddress: address(mockToken3), editId: editId });

        vm.prank(nonOwner);
        (
            Helper.BatchResult[] memory tokenResults,
            Helper.BatchResult[] memory editResults,
            uint256[3] memory tokenSummary,
            uint256[3] memory editSummary
        ) = helper.batchRejectAndRejectEdits(tokensToReject, editsToReject, "Test rejection");

        // Verify token summary shows failures
        assertEq(tokenSummary[0], 2, "Total token operations should be 2");
        assertEq(tokenSummary[1], 0, "Successful token operations should be 0");
        assertEq(tokenSummary[2], 2, "Failed token operations should be 2");

        // Verify edit summary shows failures
        assertEq(editSummary[0], 1, "Total edit operations should be 1");
        assertEq(editSummary[1], 0, "Successful edit operations should be 0");
        assertEq(editSummary[2], 1, "Failed edit operations should be 1");

        // Verify token results show unauthorized errors
        for (uint i = 0; i < tokenResults.length; i++) {
            assertFalse(tokenResults[i].success, "Token operation should fail");
            assertEq(tokenResults[i].token, tokensToReject[i], "Token address should match");
            assertEq(tokenResults[i].errorMessage, "Not authorized to reject token", "Should have authorization error");
        }

        // Verify edit results show unauthorized errors
        assertFalse(editResults[0].success, "Edit operation should fail");
        assertEq(editResults[0].token, editsToReject[0].contractAddress, "Token address should match");
        assertEq(editResults[0].editId, editsToReject[0].editId, "Edit ID should match");
        assertEq(editResults[0].errorMessage, "Not authorized to reject edit", "Should have authorization error");

        // Verify states remain unchanged
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken))), uint8(TokenStatus.PENDING));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken2))), uint8(TokenStatus.PENDING));
        assertEq(tokenRegistry.getToken(address(mockToken3)).logoURI, "https://example.com/logo.png");
    }

    function testPartiallyFailedBatchOperations() public {
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        // Setup: Add some tokens as pending
        vm.startPrank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata);
        tokenRegistry.addToken(address(mockToken2), metadata);
        tokenRegistry.addToken(address(mockToken3), metadata);
        vm.stopPrank();

        // First approve one token as owner to create edit later
        vm.prank(owner);
        tokenRegistry.approveToken(address(mockToken3));

        // Create an edit for the approved token
        vm.startPrank(nonOwner);
        MetadataInput[] memory newMetadata = new MetadataInput[](1);
        newMetadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });
        uint256 editId = tokenEdits.proposeEdit(address(mockToken3), newMetadata);
        vm.stopPrank();

        // Setup batch operations with mix of valid and invalid operations
        address[] memory tokensToApprove = new address[](3);
        tokensToApprove[0] = address(mockToken);
        tokensToApprove[1] = address(0); // Invalid address
        tokensToApprove[2] = address(mockToken2);

        Helper.BatchEdits[] memory editsToAccept = new Helper.BatchEdits[](2);
        editsToAccept[0] = Helper.BatchEdits({ contractAddress: address(mockToken3), editId: editId }); // Valid edit
        editsToAccept[1] = Helper.BatchEdits({ contractAddress: address(mockToken3), editId: 999 }); // Invalid edit ID

        // Execute batch operations as owner
        vm.prank(owner);
        (
            Helper.BatchResult[] memory tokenResults,
            Helper.BatchResult[] memory editResults,
            uint256[3] memory tokenSummary,
            uint256[3] memory editSummary
        ) = helper.batchApproveAndAcceptEdits(tokensToApprove, editsToAccept);

        // Verify token summary shows partial success
        assertEq(tokenSummary[0], 3, "Total token operations should be 3");
        assertEq(tokenSummary[1], 2, "Successful token operations should be 2");
        assertEq(tokenSummary[2], 1, "Failed token operations should be 1");

        // Verify edit summary shows partial success
        assertEq(editSummary[0], 2, "Total edit operations should be 2");
        assertEq(editSummary[1], 1, "Successful edit operations should be 1");
        assertEq(editSummary[2], 1, "Failed edit operations should be 1");

        // Verify token results
        assertTrue(tokenResults[0].success, "First token operation should succeed");
        assertFalse(tokenResults[1].success, "Second token operation should fail");
        assertTrue(tokenResults[2].success, "Third token operation should succeed");
        assertEq(tokenResults[1].errorMessage, "Invalid token address", "Should have invalid address error");

        // Verify edit results
        assertTrue(editResults[0].success, "First edit operation should succeed");
        assertFalse(editResults[1].success, "Second edit operation should fail");
        assertEq(editResults[1].errorMessage, "Edit not found", "Should have edit not found error");

        // Verify final states
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken))), uint8(TokenStatus.APPROVED));
        assertEq(uint8(tokenRegistry.tokenStatus(address(mockToken2))), uint8(TokenStatus.APPROVED));
        assertEq(tokenRegistry.getToken(address(mockToken3)).logoURI, "https://example.com/new_logo.png");
    }
}
