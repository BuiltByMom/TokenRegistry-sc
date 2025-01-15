// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/TokenRegistry.sol";
import "src/TokentrollerV1.sol";
import "src/interfaces/ITokenRegistry.sol";

contract TokenRegistryTest is Test {
    TokenRegistry tokenRegistry;
    TokentrollerV1 tokentroller;
    TokenMetadataRegistry metadataRegistry;
    address owner = address(1);
    address nonOwner = address(2);
    address nonOwner2 = address(3);
    address tokenAddress = address(4);
    uint256 chainID = 1;

    event TokenRejected(address indexed contractAddress, uint256 indexed chainID, string reason);

    function setUp() public {
        tokentroller = new TokentrollerV1(owner);
        tokenRegistry = TokenRegistry(tokentroller.tokenRegistry());
        metadataRegistry = TokenMetadataRegistry(tokentroller.metadataRegistry());
    }

    function testAddToken() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);

        (
            address contractAddress,
            address submitter,
            string memory name,
            string memory logoURI,
            string memory symbol,
            uint8 decimals,
            uint256 chainId
        ) = tokenRegistry.tokens(TokenStatus.PENDING, chainID, tokenAddress);

        assertEq(name, "Test Token");
        assertEq(symbol, "TTK");
        assertEq(logoURI, "https://example.com/logo.png");
        assertEq(decimals, 18);
        assertEq(chainID, chainID);
    }

    function testApproveToken() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);

        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        (
            address contractAddress,
            address submitter,
            string memory name,
            string memory logoURI,
            string memory symbol,
            uint8 decimals,
            uint256 chainId
        ) = tokenRegistry.tokens(TokenStatus.APPROVED, chainID, tokenAddress);
        assertEq(name, "Test Token", "Token should be fast-tracked");
    }

    function testRejectToken() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18);

        string memory reason = "Token does not meet listing criteria";
        vm.expectEmit(true, true, false, true);
        emit TokenRejected(tokenAddress, chainID, reason);

        vm.prank(owner);
        tokenRegistry.rejectToken(chainID, tokenAddress, reason);

        (
            address contractAddress,
            address submitter,
            string memory name,
            string memory logoURI,
            string memory symbol,
            uint8 decimals,
            uint256 chainId
        ) = tokenRegistry.tokens(TokenStatus.REJECTED, chainID, tokenAddress);
        assertEq(name, "Test Token", "Token should be rejected");
    }

    function testUpdateTokentroller() public {
        address newTokentroller = address(4);
        vm.prank(owner);
        tokentroller.updateRegistryTokentroller(newTokentroller);

        assertEq(tokenRegistry.tokentroller(), newTokentroller);
    }

    function testlistTokens() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(nonOwner);
            tokenRegistry.addToken(
                chainID,
                address(uint160(i + 10)),
                string(abi.encodePacked("Token ", uintToStr(i))),
                string(abi.encodePacked("TK", uintToStr(i))),
                "https://example.com/logo.png",
                18
            );
        }

        (TokenRegistry.Token[] memory tokens, uint256 total) = tokenRegistry.listTokens(
            chainID,
            0,
            3,
            TokenStatus.PENDING
        );
        assertEq(tokens.length, 3);
        assertEq(total, 5);
        assertEq(tokens[0].name, "Token 0");
        assertEq(tokens[2].name, "Token 2");

        (tokens, total) = tokenRegistry.listTokens(chainID, 3, 3, TokenStatus.PENDING);
        assertEq(tokens.length, 2);
        assertEq(total, 5);
        assertEq(tokens[0].name, "Token 3");
        assertEq(tokens[1].name, "Token 4");
    }

    function testlistTokensWithDifferentStatuses() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(nonOwner);
            tokenRegistry.addToken(
                chainID,
                address(uint160(i + 10)),
                string(abi.encodePacked("Token ", uintToStr(i))),
                string(abi.encodePacked("TK", uintToStr(i))),
                "https://example.com/logo.png",
                18
            );

            if (i % 2 == 0) {
                vm.prank(owner);
                tokenRegistry.approveToken(chainID, address(uint160(i + 10)));
            }
        }

        (TokenRegistry.Token[] memory pendingTokens, ) = tokenRegistry.listTokens(chainID, 0, 10, TokenStatus.PENDING);
        assertEq(pendingTokens.length, 2);

        (TokenRegistry.Token[] memory approvedTokens, ) = tokenRegistry.listTokens(
            chainID,
            0,
            10,
            TokenStatus.APPROVED
        );
        assertEq(approvedTokens.length, 3);

        (uint256 pending, uint256 approved, uint256 rejected) = tokenRegistry.getTokenCounts(chainID);
        assertEq(pending, 2);
        assertEq(approved, 3);
        assertEq(rejected, 0);
    }

    function testTokenCount() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(nonOwner);
            tokenRegistry.addToken(
                chainID,
                address(uint160(i + 10)),
                string(abi.encodePacked("Token ", uintToStr(i))),
                string(abi.encodePacked("TK", uintToStr(i))),
                "https://example.com/logo.png",
                18
            );
        }

        assertEq(tokenRegistry.tokenCount(chainID), 5);
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
        tokenRegistry.addToken(1, address(1), "Test Token", "TEST", "uri", 18);
        (pending, approved, rejected) = tokenRegistry.getTokenCounts(1);
        assertEq(pending, 1);
        assertEq(approved, 0);
        assertEq(rejected, 0);

        // Add another token to test rejection
        vm.prank(nonOwner);
        tokenRegistry.addToken(1, address(2), "Test Token 2", "TEST2", "uri2", 18);

        // Fast track the first token
        vm.prank(owner);
        tokenRegistry.approveToken(1, address(1));
        (pending, approved, rejected) = tokenRegistry.getTokenCounts(1);
        assertEq(pending, 1); // One token still pending
        assertEq(approved, 1);
        assertEq(rejected, 0);

        // Reject the second token
        vm.prank(owner);
        tokenRegistry.rejectToken(1, address(2), "Test reason");
        (pending, approved, rejected) = tokenRegistry.getTokenCounts(1);
        assertEq(pending, 0);
        assertEq(approved, 1);
        assertEq(rejected, 1);
    }

    function testMultiChainCounters() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(1, address(1), "Token1", "T1", "uri1", 18);
        vm.prank(nonOwner);
        tokenRegistry.addToken(2, address(2), "Token2", "T2", "uri2", 18);

        (uint256 pending1, uint256 approved1, uint256 rejected1) = tokenRegistry.getTokenCounts(1);
        assertEq(pending1, 1);
        assertEq(approved1, 0);
        assertEq(rejected1, 0);

        (uint256 pending2, uint256 approved2, uint256 rejected2) = tokenRegistry.getTokenCounts(2);
        assertEq(pending2, 1);
        assertEq(approved2, 0);
        assertEq(rejected2, 0);

        vm.prank(owner);
        tokenRegistry.approveToken(1, address(1));

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
                chainID,
                address(uint160(i + 10)),
                string(abi.encodePacked("Token ", uintToStr(i))),
                string(abi.encodePacked("TK", uintToStr(i))),
                "https://example.com/logo.png",
                18
            );
        }

        // First approve even numbered tokens (0,2,4,6,8)
        for (uint256 i = 0; i < 10; i++) {
            if (i % 2 == 0) {
                vm.prank(owner);
                tokenRegistry.approveToken(chainID, address(uint160(i + 10)));
            }
        }

        // Then reject every third token from the remaining pending tokens (3,9)
        for (uint256 i = 0; i < 10; i++) {
            if (i % 2 != 0 && i % 3 == 0) {
                vm.prank(owner);
                tokenRegistry.rejectToken(chainID, address(uint160(i + 10)), "Test reason");
            }
        }

        // Verify the counts first
        (uint256 pending, uint256 approved, uint256 rejected) = tokenRegistry.getTokenCounts(chainID);
        assertEq(pending, 3, "Should have 3 pending tokens (1,5,7)");
        assertEq(approved, 5, "Should have 5 approved tokens (0,2,4,6,8)");
        assertEq(rejected, 2, "Should have 2 rejected tokens (3,9)");

        // Test pending tokens pagination (should get tokens 1,5)
        (TokenRegistry.Token[] memory pendingTokens, uint256 pendingTotal) = tokenRegistry.listTokens(
            chainID,
            0,
            2,
            TokenStatus.PENDING
        );
        assertEq(pendingTokens.length, 2, "Should get 2 pending tokens");
        assertEq(pendingTokens[0].name, "Token 1", "First pending token should be Token 1");
        assertEq(pendingTokens[1].name, "Token 5", "Second pending token should be Token 5");
        assertEq(pendingTotal, 3, "Should have 3 pending tokens");

        // Test rejected tokens pagination (should get tokens 3,9)
        (TokenRegistry.Token[] memory rejectedTokens, uint256 rejectedTotal) = tokenRegistry.listTokens(
            chainID,
            0,
            2,
            TokenStatus.REJECTED
        );
        assertEq(rejectedTokens.length, 2, "Should get 2 rejected tokens");
        assertEq(rejectedTokens[0].name, "Token 3", "First rejected token should be Token 3");
        assertEq(rejectedTokens[1].name, "Token 9", "Second rejected token should be Token 9");
        assertEq(rejectedTotal, 2, "Should have 2 rejected tokens");

        // Get full lists to verify counts
        (TokenRegistry.Token[] memory allPending, ) = tokenRegistry.listTokens(chainID, 0, 100, TokenStatus.PENDING);
        (TokenRegistry.Token[] memory allApproved, ) = tokenRegistry.listTokens(chainID, 0, 100, TokenStatus.APPROVED);
        (TokenRegistry.Token[] memory allRejected, ) = tokenRegistry.listTokens(chainID, 0, 100, TokenStatus.REJECTED);

        assertEq(allPending.length, pending, "Full pending list length should match counter");
        assertEq(allApproved.length, approved, "Full approved list length should match counter");
        assertEq(allRejected.length, rejected, "Full rejected list length should match counter");
    }

    function testMixedStatusPagination() public {
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(nonOwner);
            tokenRegistry.addToken(
                chainID,
                address(uint160(i + 10)),
                string(abi.encodePacked("Token ", uintToStr(i))),
                string(abi.encodePacked("TK", uintToStr(i))),
                "https://example.com/logo.png",
                18
            );

            if (i % 3 == 0) {
                vm.prank(owner);
                tokenRegistry.approveToken(chainID, address(uint160(i + 10)));
            } else if (i % 3 == 1) {
                vm.prank(owner);
                tokenRegistry.rejectToken(chainID, address(uint160(i + 10)), "Test reason");
            }
        }

        (uint256 pending, uint256 approved, uint256 rejected) = tokenRegistry.getTokenCounts(chainID);
        assertEq(pending, 3);
        assertEq(approved, 4);
        assertEq(rejected, 3);

        (TokenRegistry.Token[] memory pendingTokens, ) = tokenRegistry.listTokens(chainID, 0, 10, TokenStatus.PENDING);
        assertEq(pendingTokens.length, 3);
        assertEq(pendingTokens[0].name, "Token 2");
        assertEq(pendingTokens[1].name, "Token 5");
        assertEq(pendingTokens[2].name, "Token 8");

        (TokenRegistry.Token[] memory approvedTokens, ) = tokenRegistry.listTokens(
            chainID,
            0,
            10,
            TokenStatus.APPROVED
        );
        assertEq(approvedTokens.length, 4);
        assertEq(approvedTokens[0].name, "Token 0");
        assertEq(approvedTokens[3].name, "Token 9");

        (TokenRegistry.Token[] memory rejectedTokens, ) = tokenRegistry.listTokens(
            chainID,
            0,
            10,
            TokenStatus.REJECTED
        );
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
        metadata[0] = MetadataInput({ field: "website", value: "https://example.com" });
        metadata[1] = MetadataInput({ field: "twitter", value: "@example" });

        // Add token with metadata
        vm.prank(nonOwner);
        tokenRegistry.addTokenWithMetadata(
            chainID,
            tokenAddress,
            "Test Token",
            "TEST",
            "https://logo.com",
            18,
            metadata
        );

        // Verify metadata was set
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "website"), "https://example.com");
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "twitter"), "@example");
    }

    function testCannotAddTokenWithInvalidMetadataField() public {
        // Prepare metadata inputs with invalid field
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "invalid_field", value: "some value" });

        vm.prank(nonOwner);
        vm.expectRevert("Invalid field");
        tokenRegistry.addTokenWithMetadata(
            chainID,
            tokenAddress,
            "Test Token",
            "TEST",
            "https://logo.com",
            18,
            metadata
        );
    }

    function testResubmitRejectedToken() public {
        // First submission
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TEST", "logo", 18);

        // Reject the token
        vm.prank(owner);
        tokenRegistry.rejectToken(chainID, tokenAddress, "Test reason");

        // Verify token is rejected
        (address contractAddress, , , , , , ) = tokenRegistry.tokens(TokenStatus.REJECTED, chainID, tokenAddress);
        assertEq(contractAddress, tokenAddress);
        assertEq(tokenRegistry.rejectedTokenCount(chainID), 1);
        assertEq(tokenRegistry.pendingTokenCount(chainID), 0);

        // Resubmit the token with updated information
        vm.prank(nonOwner2);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token V2", "TEST2", "logo2", 18);

        // Verify token is now pending and rejected state is cleaned up
        (
            address contractAddressPending,
            address submitter,
            string memory name,
            string memory logoURI,
            string memory symbol,
            uint8 decimals,
            uint256 chainId
        ) = tokenRegistry.tokens(TokenStatus.PENDING, chainID, tokenAddress);
        assertEq(contractAddressPending, tokenAddress);
        assertEq(name, "Test Token V2");
        assertEq(symbol, "TEST2");
        assertEq(tokenRegistry.pendingTokenCount(chainID), 1);
        assertEq(tokenRegistry.rejectedTokenCount(chainID), 0);

        // Verify rejected state is cleared
        (contractAddress, , , , , , ) = tokenRegistry.tokens(TokenStatus.REJECTED, chainID, tokenAddress);
        assertEq(contractAddress, address(0));
    }

    function testResubmitRejectedTokenCannotBypassApproval() public {
        // First submission
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TEST", "logo", 18);

        // Reject the token
        vm.prank(owner);
        tokenRegistry.rejectToken(chainID, tokenAddress, "Test reason");

        // Resubmit and try to fast-track without proper authorization
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token V2", "TEST2", "logo2", 18);

        vm.prank(nonOwner);
        vm.expectRevert("Only the owner can call this function");
        tokenRegistry.approveToken(chainID, tokenAddress);
    }

    function testCannotResubmitPendingToken() public {
        // First submission
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TEST", "logo", 18);

        // Try to resubmit while still pending
        vm.prank(nonOwner);
        vm.expectRevert("Token already exists in pending or approved state");
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token V2", "TEST2", "logo2", 18);
    }

    function testCannotResubmitApprovedToken() public {
        // First submission
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TEST", "logo", 18);

        // Approve the token
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Try to resubmit while approved
        vm.prank(nonOwner);
        vm.expectRevert("Token already exists in pending or approved state");
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token V2", "TEST2", "logo2", 18);
    }
}
