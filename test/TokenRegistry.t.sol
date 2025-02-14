// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/TokenRegistry.sol";
import "src/controllers/TokentrollerV1.sol";
import "src/interfaces/ITokenRegistry.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./mocks/MockERC20.sol";

contract TokenRegistryTest is Test {
    TokenRegistry tokenRegistry;
    TokentrollerV1 tokentroller;
    TokenMetadata tokenMetadata;
    TokenEdits tokenEdits;
    address owner = address(1);
    address nonOwner = address(2);
    address nonOwner2 = address(3);
    MockERC20 mockToken;

    event TokenRejected(address indexed contractAddress, string reason);

    function setUp() public {
        tokentroller = new TokentrollerV1(owner);
        tokenRegistry = TokenRegistry(tokentroller.tokenRegistry());
        tokenMetadata = TokenMetadata(tokentroller.tokenMetadata());
        tokenEdits = TokenEdits(tokentroller.tokenEdits());
        mockToken = new MockERC20("Test Token", "TEST", 18);
    }

    function testAddToken() public {
        vm.prank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(mockToken), metadata);

        assertEq(tokenRegistry.getToken(address(mockToken)).logoURI, "https://example.com/logo.png");
    }

    function testApproveToken() public {
        vm.prank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(mockToken), metadata);

        vm.prank(owner);
        tokenRegistry.approveToken(address(mockToken));

        assertEq(tokenRegistry.getToken(address(mockToken)).logoURI, "https://example.com/logo.png");
    }

    function testRejectToken() public {
        vm.prank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(mockToken), metadata);

        string memory reason = "Token does not meet listing criteria";
        vm.expectEmit(true, true, false, true);
        emit TokenRejected(address(mockToken), reason);

        vm.prank(owner);
        tokenRegistry.rejectToken(address(mockToken), reason);

        assertEq(tokenRegistry.getToken(address(mockToken)).logoURI, "https://example.com/logo.png");
    }

    function testUpdateTokentroller() public {
        address newTokentroller = address(4);
        vm.prank(owner);
        tokentroller.updateRegistryTokentroller(newTokentroller);

        assertEq(tokenRegistry.tokentroller(), newTokentroller);
    }

    function testlistTokens() public {
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        for (uint256 i = 0; i < 5; i++) {
            MockERC20 token = new MockERC20(
                string.concat("Token ", uintToStr(i)),
                string.concat("TKN", uintToStr(i)),
                18
            );
            vm.prank(nonOwner);
            tokenRegistry.addToken(address(token), metadata);
        }

        (ITokenRegistry.Token[] memory tokens, uint256 total) = tokenRegistry.listTokens(0, 3, TokenStatus.PENDING);
        assertEq(tokens.length, 3);
        assertEq(total, 5);

        (tokens, total) = tokenRegistry.listTokens(3, 3, TokenStatus.PENDING);
        assertEq(tokens.length, 2);
        assertEq(total, 5);
    }

    function testlistTokensWithDifferentStatuses() public {
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        MockERC20[] memory mockTokens = new MockERC20[](5);
        for (uint256 i = 0; i < 5; i++) {
            mockTokens[i] = new MockERC20(
                string.concat("Token ", uintToStr(i)),
                string.concat("TKN", uintToStr(i)),
                18
            );
            vm.prank(nonOwner);
            tokenRegistry.addToken(address(mockTokens[i]), metadata);

            if (i % 2 == 0) {
                vm.prank(owner);
                tokenRegistry.approveToken(address(mockTokens[i]));
            }
        }

        (ITokenRegistry.Token[] memory pendingTokens, ) = tokenRegistry.listTokens(0, 10, TokenStatus.PENDING);
        assertEq(pendingTokens.length, 2);

        (ITokenRegistry.Token[] memory approvedTokens, ) = tokenRegistry.listTokens(0, 10, TokenStatus.APPROVED);
        assertEq(approvedTokens.length, 3);

        (uint256 pending, uint256 approved, uint256 rejected) = tokenRegistry.getTokenCounts();
        assertEq(pending, 2);
        assertEq(approved, 3);
        assertEq(rejected, 0);
    }

    function testTokenCount() public {
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        for (uint256 i = 0; i < 5; i++) {
            MockERC20 token = new MockERC20(
                string.concat("Token ", uintToStr(i)),
                string.concat("TKN", uintToStr(i)),
                18
            );
            vm.prank(nonOwner);
            tokenRegistry.addToken(address(token), metadata);
        }

        (uint256 pending, uint256 approved, uint256 rejected) = tokenRegistry.getTokenCounts();
        assertEq(pending + approved + rejected, 5);
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
        (uint256 pending, uint256 approved, uint256 rejected) = tokenRegistry.getTokenCounts();
        assertEq(pending, 0);
        assertEq(approved, 0);
        assertEq(rejected, 0);

        // Add a token
        MockERC20 token1 = new MockERC20("Token 1", "TKN1", 18);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo1.png" });

        vm.prank(nonOwner);
        tokenRegistry.addToken(address(token1), metadata);
        (pending, approved, rejected) = tokenRegistry.getTokenCounts();
        assertEq(pending, 1);
        assertEq(approved, 0);
        assertEq(rejected, 0);

        // Add another token to test rejection
        MockERC20 token2 = new MockERC20("Token 2", "TKN2", 18);
        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo2.png" });

        vm.prank(nonOwner);
        tokenRegistry.addToken(address(token2), metadata2);

        // Fast track the first token
        vm.prank(owner);
        tokenRegistry.approveToken(address(token1));
        (pending, approved, rejected) = tokenRegistry.getTokenCounts();
        assertEq(pending, 1); // One token still pending
        assertEq(approved, 1);
        assertEq(rejected, 0);

        // Reject the second token
        vm.prank(owner);
        tokenRegistry.rejectToken(address(token2), "Test reason");
        (pending, approved, rejected) = tokenRegistry.getTokenCounts();
        assertEq(pending, 0);
        assertEq(approved, 1);
        assertEq(rejected, 1);
    }

    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function testPaginationWithStatusFilters() public {
        // Create and add 10 tokens
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        MockERC20[] memory tokens = new MockERC20[](10);
        for (uint256 i = 0; i < 10; i++) {
            tokens[i] = new MockERC20(
                string.concat("Token ", uintToString(i + 1)),
                string.concat("TKN", uintToString(i + 1)),
                18
            );
            tokenRegistry.addToken(address(tokens[i]), metadata);
        }

        // Approve tokens 3, 4, 5
        vm.prank(owner);
        tokenRegistry.approveToken(address(tokens[2]));
        vm.prank(owner);
        tokenRegistry.approveToken(address(tokens[3]));
        vm.prank(owner);
        tokenRegistry.approveToken(address(tokens[4]));

        // Reject tokens 6, 7, 8
        vm.prank(owner);
        tokenRegistry.rejectToken(address(tokens[5]), "Test rejection");
        vm.prank(owner);
        tokenRegistry.rejectToken(address(tokens[6]), "Test rejection");
        vm.prank(owner);
        tokenRegistry.rejectToken(address(tokens[7]), "Test rejection");

        // Test pagination with PENDING status
        (ITokenRegistry.Token[] memory pendingTokens, uint256 pendingTotal) = tokenRegistry.listTokens(
            0,
            3,
            TokenStatus.PENDING
        );
        assertEq(pendingTotal, 4);
        assertEq(pendingTokens.length, 3);
        assertEq(pendingTokens[0].name, "Token 1");
        assertEq(pendingTokens[1].name, "Token 2");
        assertEq(pendingTokens[2].name, "Token 10");

        // Test pagination with APPROVED status
        (ITokenRegistry.Token[] memory approvedTokens, uint256 approvedTotal) = tokenRegistry.listTokens(
            0,
            3,
            TokenStatus.APPROVED
        );
        assertEq(approvedTotal, 3);
        assertEq(approvedTokens.length, 3);
        assertEq(approvedTokens[0].name, "Token 3");
        assertEq(approvedTokens[1].name, "Token 4");
        assertEq(approvedTokens[2].name, "Token 5");

        // Test pagination with REJECTED status
        (ITokenRegistry.Token[] memory rejectedTokens, uint256 rejectedTotal) = tokenRegistry.listTokens(
            0,
            3,
            TokenStatus.REJECTED
        );
        assertEq(rejectedTotal, 3);
        assertEq(rejectedTokens.length, 3);
        assertEq(rejectedTokens[0].name, "Token 6");
        assertEq(rejectedTokens[1].name, "Token 7");
        assertEq(rejectedTokens[2].name, "Token 8");
    }

    function testMixedStatusPagination() public {
        MockERC20[] memory mockTokens = new MockERC20[](10);

        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });

        for (uint256 i = 0; i < 10; i++) {
            mockTokens[i] = new MockERC20(
                string.concat("Token ", uintToStr(i)),
                string.concat("TKN", uintToStr(i)),
                18
            );
            vm.prank(nonOwner);
            tokenRegistry.addToken(address(mockTokens[i]), metadata);

            if (i % 3 == 0) {
                vm.prank(owner);
                tokenRegistry.approveToken(address(mockTokens[i]));
            } else if (i % 3 == 1) {
                vm.prank(owner);
                tokenRegistry.rejectToken(address(mockTokens[i]), "Test reason");
            }
        }

        (uint256 pending, uint256 approved, uint256 rejected) = tokenRegistry.getTokenCounts();
        assertEq(pending, 3);
        assertEq(approved, 4);
        assertEq(rejected, 3);

        (ITokenRegistry.Token[] memory pendingTokens, ) = tokenRegistry.listTokens(0, 10, TokenStatus.PENDING);
        assertEq(pendingTokens.length, 3);
        assertEq(pendingTokens[0].name, "Token 2");
        assertEq(pendingTokens[1].name, "Token 5");
        assertEq(pendingTokens[2].name, "Token 8");

        (ITokenRegistry.Token[] memory approvedTokens, ) = tokenRegistry.listTokens(0, 10, TokenStatus.APPROVED);
        assertEq(approvedTokens.length, 4);
        assertEq(approvedTokens[0].name, "Token 0");
        assertEq(approvedTokens[3].name, "Token 9");

        (ITokenRegistry.Token[] memory rejectedTokens, ) = tokenRegistry.listTokens(0, 10, TokenStatus.REJECTED);
        assertEq(rejectedTokens.length, 3);
        assertEq(rejectedTokens[0].name, "Token 1");
        assertEq(rejectedTokens[2].name, "Token 7");
    }

    function testResubmitRejectedToken() public {
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        // First submission
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata);

        // Reject the token
        vm.prank(owner);
        tokenRegistry.rejectToken(address(mockToken), "Test reason");

        // Verify token is rejected
        assertEq(tokenRegistry.getToken(address(mockToken)).logoURI, "https://example.com/logo.png");
        (uint256 pending, uint256 approved, uint256 rejected) = tokenRegistry.getTokenCounts();
        assertEq(pending, 0);
        assertEq(approved, 0);
        assertEq(rejected, 1);

        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo2.png" });
        // Resubmit the token with updated information
        vm.prank(nonOwner2);
        tokenRegistry.addToken(address(mockToken), metadata2);

        // Verify token is now pending and rejected state is cleaned up
        assertEq(tokenRegistry.getToken(address(mockToken)).logoURI, "https://example.com/logo2.png");
        (pending, approved, rejected) = tokenRegistry.getTokenCounts();
        assertEq(pending, 1);
        assertEq(approved, 0);
        assertEq(rejected, 0);

        TokenStatus status = tokenRegistry.tokenStatus(address(mockToken));
        // Verify rejected state is cleared
        assertEq(uint8(status), uint8(TokenStatus.PENDING));
    }

    function testResubmitRejectedTokenCannotBypassApproval() public {
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        // First submission
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata);

        // Reject the token
        vm.prank(owner);
        tokenRegistry.rejectToken(address(mockToken), "Test reason");

        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo2.png" });

        // Resubmit and try to fast-track without proper authorization
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata2);

        vm.prank(nonOwner);
        vm.expectRevert("Not authorized to approve token");
        tokenRegistry.approveToken(address(mockToken));
    }

    function testCannotResubmitPendingToken() public {
        // First submission
        vm.prank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(mockToken), metadata);

        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo2.png" });

        // Try to resubmit while still pending
        vm.prank(nonOwner);
        vm.expectRevert("Token already exists in pending or approved state");
        tokenRegistry.addToken(address(mockToken), metadata2);
    }

    function testCannotResubmitApprovedToken() public {
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        // First submission
        vm.prank(nonOwner);
        tokenRegistry.addToken(address(mockToken), metadata);

        // Approve the token
        vm.prank(owner);
        tokenRegistry.approveToken(address(mockToken));

        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo2.png" });
        // Try to resubmit while approved
        vm.prank(nonOwner);
        vm.expectRevert("Token already exists in pending or approved state");
        tokenRegistry.addToken(address(mockToken), metadata2);
    }

    function testGetTokenWithMetadata() public {
        // Add a token with metadata
        vm.startPrank(nonOwner);
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo.png" });
        tokenRegistry.addToken(address(mockToken), metadata);
        vm.stopPrank();

        // Add additional metadata fields
        vm.startPrank(owner);
        tokenRegistry.approveToken(address(mockToken));
        tokenMetadata.addField("website");
        tokenMetadata.addField("twitter");
        vm.stopPrank();

        // Set additional metadata
        vm.startPrank(nonOwner);
        MetadataInput[] memory additionalMetadata = new MetadataInput[](2);
        additionalMetadata[0] = MetadataInput({ field: "website", value: "https://example.com" });
        additionalMetadata[1] = MetadataInput({ field: "twitter", value: "@example" });
        tokenEdits.proposeEdit(address(mockToken), additionalMetadata);
        vm.stopPrank();

        vm.startPrank(owner);
        tokenEdits.acceptEdit(address(mockToken), 1);
        vm.stopPrank();

        // Get token with metadata
        ITokenRegistry.Token memory token = tokenRegistry.getToken(address(mockToken), true);

        // Verify token data
        assertEq(token.contractAddress, address(mockToken));
        assertEq(token.name, "Test Token");
        assertEq(token.symbol, "TEST");
        assertEq(token.decimals, 18);

        // Verify metadata
        assertEq(token.metadata.length, 3);

        // Verify logoURI field
        assertEq(token.metadata[0].field, "logoURI");
        assertEq(token.metadata[0].value, "https://example.com/logo.png");
        assertTrue(token.metadata[0].isActive);

        // Verify website field
        assertEq(token.metadata[1].field, "website");
        assertEq(token.metadata[1].value, "https://example.com");
        assertTrue(token.metadata[1].isActive);

        // Verify twitter field
        assertEq(token.metadata[2].field, "twitter");
        assertEq(token.metadata[2].value, "@example");
        assertTrue(token.metadata[2].isActive);
    }

    function testGetTokens() public {
        // Create and add multiple tokens
        MockERC20 mockToken2 = new MockERC20("Test Token 2", "TEST2", 6);
        MockERC20 mockToken3 = new MockERC20("Test Token 3", "TEST3", 8);

        vm.startPrank(nonOwner);

        // Add first token
        MetadataInput[] memory metadata1 = new MetadataInput[](1);
        metadata1[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo1.png" });
        tokenRegistry.addToken(address(mockToken), metadata1);

        // Add second token
        MetadataInput[] memory metadata2 = new MetadataInput[](1);
        metadata2[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo2.png" });
        tokenRegistry.addToken(address(mockToken2), metadata2);

        // Add third token
        MetadataInput[] memory metadata3 = new MetadataInput[](1);
        metadata3[0] = MetadataInput({ field: "logoURI", value: "https://example.com/logo3.png" });
        tokenRegistry.addToken(address(mockToken3), metadata3);

        vm.stopPrank();

        // Create array of addresses to query
        address[] memory addresses = new address[](3);
        addresses[0] = address(mockToken);
        addresses[1] = address(mockToken2);
        addresses[2] = address(mockToken3);

        // Get tokens
        ITokenRegistry.Token[] memory tokens = tokenRegistry.getTokens(addresses);

        // Verify length
        assertEq(tokens.length, 3);

        // Verify first token
        assertEq(tokens[0].contractAddress, address(mockToken));
        assertEq(tokens[0].name, "Test Token");
        assertEq(tokens[0].symbol, "TEST");
        assertEq(tokens[0].decimals, 18);
        assertEq(tokens[0].logoURI, "https://example.com/logo1.png");

        // Verify second token
        assertEq(tokens[1].contractAddress, address(mockToken2));
        assertEq(tokens[1].name, "Test Token 2");
        assertEq(tokens[1].symbol, "TEST2");
        assertEq(tokens[1].decimals, 6);
        assertEq(tokens[1].logoURI, "https://example.com/logo2.png");

        // Verify third token
        assertEq(tokens[2].contractAddress, address(mockToken3));
        assertEq(tokens[2].name, "Test Token 3");
        assertEq(tokens[2].symbol, "TEST3");
        assertEq(tokens[2].decimals, 8);
        assertEq(tokens[2].logoURI, "https://example.com/logo3.png");
    }
}
