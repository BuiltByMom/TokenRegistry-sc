// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/TokenRegistry.sol";
import "src/TokentrollerV1.sol";
import "src/TokenMetadataRegistry.sol";

contract TokenRegistryTest is Test {
    TokenRegistry tokenRegistry;
    TokentrollerV1 tokentroller;
    TokenMetadataRegistry metadataRegistry;
    address owner = address(1);
    address nonOwner = address(2);
    address nonOwner2 = address(3);
    address tokenAddress = address(4);
    uint256 chainID = 1;

    function setUp() public {
        tokentroller = new TokentrollerV1(owner);
        tokenRegistry = TokenRegistry(tokentroller.tokenRegistry());
        metadataRegistry = TokenMetadataRegistry(tokentroller.metadataRegistry());
    }

    function testAddToken() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);

        (address contractAddress, address submitter, string memory name, string memory logoURI, string memory symbol, uint8 decimals, uint256 chainId) = tokenRegistry.tokens(chainID, tokenAddress, 0);

        assertEq(name, "Test Token");
        assertEq(symbol, "TTK");
        assertEq(logoURI, "https://example.com/logo.png");
        assertEq(decimals, 18);
        assertEq(chainID, chainID);
    }

    function testUpdateToken() public {
        // First add and approve the token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);
        
        // Fast track the token to approved status
        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);
 
        // Now update the approved token
        vm.prank(nonOwner);
        tokenRegistry.updateToken(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9, chainID);

        // Check that the edit is stored in editsOnTokens, not directly updated
        (address contractAddress, address submitter, string memory name, string memory logoURI, string memory symbol, uint8 decimals, uint256 chainId) = tokenRegistry.editsOnTokens(chainID, tokenAddress, 1);

        assertEq(name, "Updated Token", "Name should be in edit");
        assertEq(symbol, "UTK", "Symbol should be in edit");
        assertEq(logoURI, "https://example.com/new_logo.png", "Logo URI should be in edit");
        assertEq(decimals, 9, "Decimals should be in edit");
    }

    function testCannotUpdateNonApprovedToken() public {
        // Add token but don't approve it
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);
        
        // Try to update pending token
        vm.prank(nonOwner);
        vm.expectRevert("Token does not exist");
        tokenRegistry.updateToken(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9, chainID);
    }

    function testCannotUpdateRejectedToken() public {
        // Add and reject the token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);
        
        vm.prank(owner);
        tokenRegistry.rejectToken(chainID, tokenAddress);
        
        // Try to update rejected token
        vm.prank(nonOwner);
        vm.expectRevert("Token does not exist");
        tokenRegistry.updateToken(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9, chainID);
    }

    function testFastTrackToken() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);

        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        (address contractAddress, address submitter, string memory name, string memory logoURI, string memory symbol, uint8 decimals, uint256 chainId) = tokenRegistry.tokens(chainID, tokenAddress, 1);
        assertEq(name, "Test Token", 'Token should be fast-tracked');
    }

    function testRejectToken() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);

        vm.prank(owner);
        tokenRegistry.rejectToken(chainID, tokenAddress);

        (address contractAddress, address submitter, string memory name, string memory logoURI, string memory symbol, uint8 decimals, uint256 chainId) = tokenRegistry.tokens(chainID, tokenAddress, 2);
        assertEq(name, "Test Token", "Token should be rejected");
    }

    function testUpdateTokentroller() public {
        address newTokentroller = address(4);
        vm.prank(owner);
        tokentroller.updateRegistryTokentroller(newTokentroller);

        assertEq(tokenRegistry.tokentroller(), newTokentroller);
    }

    function testListAllTokens() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(nonOwner);
            tokenRegistry.addToken(address(uint160(i + 10)), string(abi.encodePacked("Token ", uintToStr(i))), string(abi.encodePacked("TK", uintToStr(i))), "https://example.com/logo.png", 18, chainID);
        }

        (TokenRegistry.Token[] memory tokens, uint256 finalIndex, bool hasMore) = tokenRegistry.listAllTokens(chainID, 0, 3, 0);
        assertEq(tokens.length, 3);
        assertEq(finalIndex, 2);
        assertTrue(hasMore);
        assertEq(tokens[0].name, "Token 0");
        assertEq(tokens[2].name, "Token 2");

        (tokens, finalIndex, hasMore) = tokenRegistry.listAllTokens(chainID, 3, 3, 0);
        assertEq(tokens.length, 2);
        assertEq(finalIndex, 4);
        assertFalse(hasMore);
    }

    function testListAllTokensWithDifferentStatuses() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(nonOwner);
            tokenRegistry.addToken(
                address(uint160(i + 10)), 
                string(abi.encodePacked("Token ", uintToStr(i))), 
                string(abi.encodePacked("TK", uintToStr(i))), 
                "https://example.com/logo.png", 
                18, 
                chainID
            );
            
            if (i % 2 == 0) {
                vm.prank(owner);
                tokenRegistry.fastTrackToken(chainID, address(uint160(i + 10)));
            }
        }

        (TokenRegistry.Token[] memory pendingTokens, uint256 pendingFinalIndex, bool hasMorePending) = 
            tokenRegistry.listAllTokens(chainID, 0, 10, 0);
        assertEq(pendingTokens.length, 2);

        (TokenRegistry.Token[] memory approvedTokens, uint256 approvedFinalIndex, bool hasMoreApproved) = 
            tokenRegistry.listAllTokens(chainID, 0, 10, 1);
        assertEq(approvedTokens.length, 3);

        (uint256 pending, uint256 approved, uint256 rejected) = tokenRegistry.getTokenCounts(chainID);
        assertEq(pending, 2);
        assertEq(approved, 3);
        assertEq(rejected, 0);
    }

    function testTokenCount() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(nonOwner);
            tokenRegistry.addToken(address(uint160(i + 10)), string(abi.encodePacked("Token ", uintToStr(i))), string(abi.encodePacked("TK", uintToStr(i))), "https://example.com/logo.png", 18, chainID);
        }

        assertEq(tokenRegistry.tokenCount(chainID), 5);
    }

    function testAcceptTokenEdit() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);

        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        vm.prank(nonOwner2);
        tokenRegistry.updateToken(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9, chainID);

        vm.prank(owner);
        tokenRegistry.acceptTokenEdit(tokenAddress, 1, chainID);

        (address contractAddress, address submitter, string memory name, string memory logoURI, string memory symbol, uint8 decimals, uint256 chainId) = tokenRegistry.tokens(chainID, tokenAddress, 1);

        assertEq(name, "Updated Token", 'Name should be updated');
        assertEq(symbol, "UTK", 'Symbol should be updated');
        assertEq(logoURI, "https://example.com/new_logo.png", 'Logo URI should be updated');
        assertEq(decimals, 9, 'Decimals should be updated');
        assertEq(chainId, chainID);
    }

    function testUpdateOwner() public {
        address newOwner = address(5);
        vm.prank(owner);
        tokentroller.updateOwner(newOwner);

        assertEq(tokentroller.owner(), newOwner);
    }

    function uintToStr(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bstr[k] = bytes1(temp);
            _i /= 10;
        }
        return string(bstr);
    }

    function testTokenCounters() public {
        // Initial counts should be zero
        (uint256 pending, uint256 approved, uint256 rejected) = tokenRegistry.getTokenCounts(1);
        assertEq(pending, 0);
        assertEq(approved, 0);
        assertEq(rejected, 0);

        // Add a token
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(1), "Test Token", "TEST", "uri", 18, 1);
        (pending, approved, rejected) = tokenRegistry.getTokenCounts(1);
        assertEq(pending, 1);
        assertEq(approved, 0);
        assertEq(rejected, 0);

        // Add another token to test rejection
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(2), "Test Token 2", "TEST2", "uri2", 18, 1);

        // Fast track the first token
        vm.prank(owner);
        tokenRegistry.fastTrackToken(1, address(1));
        (pending, approved, rejected) = tokenRegistry.getTokenCounts(1);
        assertEq(pending, 1); // One token still pending
        assertEq(approved, 1);
        assertEq(rejected, 0);

        // Reject the second token
        vm.prank(owner);
        tokenRegistry.rejectToken(1, address(2));
        (pending, approved, rejected) = tokenRegistry.getTokenCounts(1);
        assertEq(pending, 0);
        assertEq(approved, 1);
        assertEq(rejected, 1);
    }

    function testMultiChainCounters() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(1), "Token1", "T1", "uri1", 18, 1);
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(2), "Token2", "T2", "uri2", 18, 2);
        
        (uint256 pending1, uint256 approved1, uint256 rejected1) = tokenRegistry.getTokenCounts(1);
        assertEq(pending1, 1);
        assertEq(approved1, 0);
        assertEq(rejected1, 0);

        (uint256 pending2, uint256 approved2, uint256 rejected2) = tokenRegistry.getTokenCounts(2);
        assertEq(pending2, 1);
        assertEq(approved2, 0);
        assertEq(rejected2, 0);

        vm.prank(owner);
        tokenRegistry.fastTrackToken(1, address(1));

        (pending1, approved1, rejected1) = tokenRegistry.getTokenCounts(1);
        assertEq(pending1, 0);
        assertEq(approved1, 1);
        assertEq(rejected1, 0);

        (pending2, approved2, rejected2) = tokenRegistry.getTokenCounts(2);
        assertEq(pending2, 1);
        assertEq(approved2, 0);
        assertEq(rejected2, 0);
    }

    function testPaginationWithStatusFilters() public {
        // Add 10 tokens
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(nonOwner);
            tokenRegistry.addToken(
                address(uint160(i + 10)), 
                string(abi.encodePacked("Token ", uintToStr(i))), 
                string(abi.encodePacked("TK", uintToStr(i))), 
                "https://example.com/logo.png", 
                18, 
                chainID
            );
        }

        // First fast track even numbered tokens (0,2,4,6,8)
        for (uint256 i = 0; i < 10; i++) {
            if (i % 2 == 0) {
                vm.prank(owner);
                tokenRegistry.fastTrackToken(chainID, address(uint160(i + 10)));
            }
        }

        // Then reject every third token from the remaining pending tokens (3,9)
        for (uint256 i = 0; i < 10; i++) {
            if (i % 2 != 0 && i % 3 == 0) {
                vm.prank(owner);
                tokenRegistry.rejectToken(chainID, address(uint160(i + 10)));
            }
        }

        // Verify the counts first
        (uint256 pending, uint256 approved, uint256 rejected) = tokenRegistry.getTokenCounts(chainID);
        assertEq(pending, 3, "Should have 3 pending tokens (1,5,7)");
        assertEq(approved, 5, "Should have 5 approved tokens (0,2,4,6,8)");
        assertEq(rejected, 2, "Should have 2 rejected tokens (3,9)");

        // Test pending tokens pagination (should get tokens 1,5)
        (TokenRegistry.Token[] memory pendingTokens, uint256 pendingFinalIndex, bool hasMorePending) = 
            tokenRegistry.listAllTokens(chainID, 0, 2, 0);
        assertEq(pendingTokens.length, 2, "Should get 2 pending tokens");
        assertEq(pendingTokens[0].name, "Token 1", "First pending token should be Token 1");
        assertEq(pendingTokens[1].name, "Token 5", "Second pending token should be Token 5");
        assertTrue(hasMorePending, "Should have one more pending token");

        // Test rejected tokens pagination (should get tokens 3,9)
        (TokenRegistry.Token[] memory rejectedTokens, uint256 rejectedFinalIndex, bool hasMoreRejected) = 
            tokenRegistry.listAllTokens(chainID, 0, 2, 2);
        assertEq(rejectedTokens.length, 2, "Should get 2 rejected tokens");
        assertEq(rejectedTokens[0].name, "Token 3", "First rejected token should be Token 3");
        assertEq(rejectedTokens[1].name, "Token 9", "Second rejected token should be Token 9");
        assertFalse(hasMoreRejected, "Should not have more rejected tokens");

        // Get full lists to verify counts
        (TokenRegistry.Token[] memory allPending,,) = tokenRegistry.listAllTokens(chainID, 0, 100, 0);
        (TokenRegistry.Token[] memory allApproved,,) = tokenRegistry.listAllTokens(chainID, 0, 100, 1);
        (TokenRegistry.Token[] memory allRejected,,) = tokenRegistry.listAllTokens(chainID, 0, 100, 2);
        
        assertEq(allPending.length, pending, "Full pending list length should match counter");
        assertEq(allApproved.length, approved, "Full approved list length should match counter");
        assertEq(allRejected.length, rejected, "Full rejected list length should match counter");
    }

    function testMixedStatusPagination() public {
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(nonOwner);
            tokenRegistry.addToken(
                address(uint160(i + 10)), 
                string(abi.encodePacked("Token ", uintToStr(i))), 
                string(abi.encodePacked("TK", uintToStr(i))), 
                "https://example.com/logo.png", 
                18, 
                chainID
            );
            
            if (i % 3 == 0) {
                vm.prank(owner);
                tokenRegistry.fastTrackToken(chainID, address(uint160(i + 10)));
            } else if (i % 3 == 1) {
                vm.prank(owner);
                tokenRegistry.rejectToken(chainID, address(uint160(i + 10)));
            }
        }

        (uint256 pending, uint256 approved, uint256 rejected) = tokenRegistry.getTokenCounts(chainID);
        assertEq(pending, 3);
        assertEq(approved, 4);
        assertEq(rejected, 3);

        (TokenRegistry.Token[] memory pendingTokens,,) = tokenRegistry.listAllTokens(chainID, 0, 10, 0);
        assertEq(pendingTokens.length, 3);
        assertEq(pendingTokens[0].name, "Token 2");
        assertEq(pendingTokens[1].name, "Token 5");
        assertEq(pendingTokens[2].name, "Token 8");

        (TokenRegistry.Token[] memory approvedTokens,,) = tokenRegistry.listAllTokens(chainID, 0, 10, 1);
        assertEq(approvedTokens.length, 4);
        assertEq(approvedTokens[0].name, "Token 0");
        assertEq(approvedTokens[3].name, "Token 9");

        (TokenRegistry.Token[] memory rejectedTokens,,) = tokenRegistry.listAllTokens(chainID, 0, 10, 2);
        assertEq(rejectedTokens.length, 3);
        assertEq(rejectedTokens[0].name, "Token 1");
        assertEq(rejectedTokens[2].name, "Token 7");
    }

    function testAddTokenWithMetadata() public {
        // Add fields first
        vm.startPrank(owner);
        metadataRegistry.addMetadataField("website");
        metadataRegistry.addMetadataField("twitter");
        vm.stopPrank();

        // Prepare metadata inputs
        MetadataInput[] memory metadata = new MetadataInput[](2);
        metadata[0] = MetadataInput({
            field: "website",
            value: "https://example.com"
        });
        metadata[1] = MetadataInput({
            field: "twitter",
            value: "@example"
        });

        // Add token with metadata
        vm.prank(nonOwner);
        tokenRegistry.addTokenWithMetadata(
            tokenAddress,
            "Test Token",
            "TEST",
            "https://logo.com",
            18,
            chainID,
            metadata
        );

        // Verify metadata was set
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "website"), "https://example.com");
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "twitter"), "@example");
    }

    function testCannotAddTokenWithInvalidMetadataField() public {
        // Prepare metadata inputs with invalid field
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({
            field: "invalid_field",
            value: "some value"
        });

        vm.prank(nonOwner);
        vm.expectRevert("Invalid field");
        tokenRegistry.addTokenWithMetadata(
            tokenAddress,
            "Test Token",
            "TEST",
            "https://logo.com",
            18,
            chainID,
            metadata
        );
    }

    function testRejectTokenEdit() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);
        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Create edit
        vm.prank(nonOwner);
        tokenRegistry.updateToken(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9, chainID);

        // Reject the edit
        vm.prank(owner);
        tokenRegistry.rejectTokenEdit(tokenAddress, 1, chainID);

        // Verify edit was cleared
        (address contractAddress,,,,,,) = tokenRegistry.editsOnTokens(chainID, tokenAddress, 1);
        assertEq(contractAddress, address(0), "Edit should be cleared");
    }

    function testCannotRejectTokenEditWithoutPermission() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);
        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Create edit
        vm.prank(nonOwner);
        tokenRegistry.updateToken(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9, chainID);

        // Try to reject without permission
        vm.prank(nonOwner);
        vm.expectRevert("Failed to reject token edit");
        tokenRegistry.rejectTokenEdit(tokenAddress, 1, chainID);
    }

    function testAcceptTokenEditClearsOtherEdits() public {
        // Add and approve token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);
        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Create multiple edits
        vm.prank(nonOwner);
        tokenRegistry.updateToken(tokenAddress, "Updated Token 1", "UT1", "https://example.com/logo1.png", 9, chainID);
        vm.prank(nonOwner);
        tokenRegistry.updateToken(tokenAddress, "Updated Token 2", "UT2", "https://example.com/logo2.png", 12, chainID);

        // Accept first edit
        vm.prank(owner);
        tokenRegistry.acceptTokenEdit(tokenAddress, 1, chainID);

        // Verify second edit was cleared
        (address contractAddress,,,,,,) = tokenRegistry.editsOnTokens(chainID, tokenAddress, 2);
        assertEq(contractAddress, address(0), "Second edit should be cleared");
        
        // Verify edit count was reset
        assertEq(tokenRegistry.editCount(chainID, tokenAddress), 0, "Edit count should be reset");
    }

    function testEditTracking() public {
        // Add and approve a token first
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);
        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Verify no edits initially
        assertEq(tokenRegistry.tokensWithEditsLength(chainID), 0);

        // Create first edit
        vm.prank(nonOwner);
        tokenRegistry.updateToken(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9, chainID);

        // Verify token is tracked
        assertEq(tokenRegistry.tokensWithEditsLength(chainID), 1);
        assertEq(tokenRegistry.getTokensWithEdits(chainID, 0), tokenAddress);
        assertEq(tokenRegistry.editCount(chainID, tokenAddress), 1);

        // Create second edit
        vm.prank(nonOwner2);
        tokenRegistry.updateToken(tokenAddress, "Updated Token 2", "UTK2", "https://example.com/new_logo2.png", 12, chainID);

        // Verify tracking remains correct
        assertEq(tokenRegistry.tokensWithEditsLength(chainID), 1);
        assertEq(tokenRegistry.editCount(chainID, tokenAddress), 2);
    }

    function testListEdits() public {
        // Add and approve a token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);
        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Create multiple edits
        vm.prank(nonOwner);
        tokenRegistry.updateToken(tokenAddress, "Updated Token 1", "UT1", "https://example.com/logo1.png", 9, chainID);
        vm.prank(nonOwner2);
        tokenRegistry.updateToken(tokenAddress, "Updated Token 2", "UT2", "https://example.com/logo2.png", 12, chainID);

        // Test listing with pagination
        (TokenRegistry.TokenEdit[] memory edits, uint256 finalIndex, bool hasMore) = tokenRegistry.listAllEdits(chainID, 0, 1);
        
        assertEq(edits.length, 1);
        assertEq(edits[0].name, "Updated Token 1");
        assertEq(edits[0].editIndex, 1);
        assertTrue(hasMore);

        // Get second page
        (edits, finalIndex, hasMore) = tokenRegistry.listAllEdits(chainID, 1, 1);
        
        assertEq(edits.length, 1);
        assertEq(edits[0].name, "Updated Token 2");
        assertEq(edits[0].editIndex, 2);
        assertFalse(hasMore);
    }

    function testRemoveEditTracking() public {
        // Add and approve a token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);
        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Create an edit
        vm.prank(nonOwner);
        tokenRegistry.updateToken(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9, chainID);

        // Reject the edit
        vm.prank(owner);
        tokenRegistry.rejectTokenEdit(tokenAddress, 1, chainID);

        // Verify token is no longer tracked
        assertEq(tokenRegistry.tokensWithEditsLength(chainID), 0);
        assertEq(tokenRegistry.editCount(chainID, tokenAddress), 0);
    }

    function testMultipleTokenEdits() public {
        address token2 = address(5);

        // Add and approve two tokens
        vm.startPrank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token 1", "TT1", "https://example.com/logo1.png", 18, chainID);
        tokenRegistry.addToken(token2, "Test Token 2", "TT2", "https://example.com/logo2.png", 18, chainID);
        vm.stopPrank();

        vm.startPrank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);
        tokenRegistry.fastTrackToken(chainID, token2);
        vm.stopPrank();

        // Create edits for both tokens
        vm.prank(nonOwner);
        tokenRegistry.updateToken(tokenAddress, "Updated Token 1", "UT1", "https://example.com/new_logo1.png", 9, chainID);
        vm.prank(nonOwner2);
        tokenRegistry.updateToken(token2, "Updated Token 2", "UT2", "https://example.com/new_logo2.png", 12, chainID);

        // Verify tracking
        assertEq(tokenRegistry.tokensWithEditsLength(chainID), 2);
        assertEq(tokenRegistry.getTokensWithEdits(chainID, 0), tokenAddress);
        assertEq(tokenRegistry.getTokensWithEdits(chainID, 1), token2);
        
        // List all edits
        (TokenRegistry.TokenEdit[] memory edits, uint256 finalIndex, bool hasMore) = tokenRegistry.listAllEdits(chainID, 0, 10);
        
        assertEq(edits.length, 2);
        assertEq(edits[0].contractAddress, tokenAddress);
        assertEq(edits[1].contractAddress, token2);
    }

    function testAcceptEditClearsTracking() public {
        // Add and approve a token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);
        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        // Create multiple edits
        vm.prank(nonOwner);
        tokenRegistry.updateToken(tokenAddress, "Updated Token 1", "UT1", "https://example.com/logo1.png", 9, chainID);
        vm.prank(nonOwner2);
        tokenRegistry.updateToken(tokenAddress, "Updated Token 2", "UT2", "https://example.com/logo2.png", 12, chainID);

        // Accept first edit
        vm.prank(owner);
        tokenRegistry.acceptTokenEdit(tokenAddress, 1, chainID);

        // Verify all tracking is cleared
        assertEq(tokenRegistry.tokensWithEditsLength(chainID), 0);
        assertEq(tokenRegistry.editCount(chainID, tokenAddress), 0);

        // Verify token was updated with accepted edit
        (address contractAddress, , string memory name, , string memory symbol, uint8 decimals,) = 
            tokenRegistry.tokens(chainID, tokenAddress, 1);
        
        assertEq(contractAddress, tokenAddress);
        assertEq(name, "Updated Token 1");
        assertEq(symbol, "UT1");
        assertEq(decimals, 9);
    }
}
