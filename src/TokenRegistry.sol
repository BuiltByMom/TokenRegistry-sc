// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interfaces/ITokenRegistry.sol";
import "./interfaces/ITokentroller.sol";
import "./interfaces/ITokenMetadata.sol";
import "./interfaces/ISharedTypes.sol";

contract TokenRegistry is ITokenRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(TokenStatus => EnumerableSet.AddressSet) private tokensByStatus;
    ITokenMetadata public tokenMetadata;

    address public tokentroller;

    constructor(address _tokentroller, address _tokenMetadata) {
        tokentroller = _tokentroller;
        tokenMetadata = ITokenMetadata(_tokenMetadata);
    }

    function addToken(address contractAddress, MetadataInput[] calldata metadata) external {
        require(ITokentroller(tokentroller).canAddToken(msg.sender, contractAddress), "Not authorized to add token");

        // Verify it's a valid ERC20 token
        IERC20Metadata token = IERC20Metadata(contractAddress);
        token.name(); // Will revert if not implemented
        token.symbol();
        token.decimals();

        require(
            !tokensByStatus[TokenStatus.PENDING].contains(contractAddress) &&
                !tokensByStatus[TokenStatus.APPROVED].contains(contractAddress),
            "Token already exists in pending or approved state"
        );

        // Remove from rejected if exists
        if (tokensByStatus[TokenStatus.REJECTED].contains(contractAddress)) {
            tokensByStatus[TokenStatus.REJECTED].remove(contractAddress);
        }

        tokenMetadata.updateMetadata(contractAddress, metadata);
        tokensByStatus[TokenStatus.PENDING].add(contractAddress);

        emit TokenAdded(contractAddress, msg.sender);
    }

    function _getToken(address contractAddress) internal view returns (Token memory) {
        return
            Token({
                contractAddress: contractAddress,
                name: IERC20Metadata(contractAddress).name(),
                symbol: IERC20Metadata(contractAddress).symbol(),
                decimals: IERC20Metadata(contractAddress).decimals(),
                logoURI: tokenMetadata.getMetadata(contractAddress, "logoURI")
            });
    }

    function getToken(address contractAddress) external view returns (Token memory) {
        return _getToken(contractAddress);
    }

    function listTokens(
        uint256 offset,
        uint256 limit,
        TokenStatus status
    ) external view returns (Token[] memory tokens, uint256 total) {
        EnumerableSet.AddressSet storage statusSet = tokensByStatus[status];
        total = statusSet.length();

        if (offset >= total) {
            return (new Token[](0), total);
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        uint256 resultLength = end - offset;
        tokens = new Token[](resultLength);

        for (uint256 i = 0; i < resultLength; i++) {
            address tokenAddress = statusSet.at(offset + i);
            tokens[i] = _getToken(tokenAddress);
        }
    }

    function tokenStatus(address contractAddress) external view returns (TokenStatus) {
        if (tokensByStatus[TokenStatus.APPROVED].contains(contractAddress)) {
            return TokenStatus.APPROVED;
        } else if (tokensByStatus[TokenStatus.PENDING].contains(contractAddress)) {
            return TokenStatus.PENDING;
        } else if (tokensByStatus[TokenStatus.REJECTED].contains(contractAddress)) {
            return TokenStatus.REJECTED;
        } else {
            return TokenStatus.NONE;
        }
    }

    function approveToken(address contractAddress) external {
        require(
            ITokentroller(tokentroller).canApproveToken(msg.sender, contractAddress),
            "Not authorized to approve token"
        );

        require(tokensByStatus[TokenStatus.PENDING].contains(contractAddress), "Token not found in pending state");

        tokensByStatus[TokenStatus.PENDING].remove(contractAddress);
        tokensByStatus[TokenStatus.APPROVED].add(contractAddress);

        emit TokenApproved(contractAddress);
    }

    function rejectToken(address contractAddress, string calldata reason) external {
        require(
            ITokentroller(tokentroller).canRejectToken(msg.sender, contractAddress),
            "Not authorized to reject token"
        );

        require(tokensByStatus[TokenStatus.PENDING].contains(contractAddress), "Token not found in pending state");

        tokensByStatus[TokenStatus.PENDING].remove(contractAddress);
        tokensByStatus[TokenStatus.REJECTED].add(contractAddress);

        emit TokenRejected(contractAddress, reason);
    }

    function updateTokentroller(address newTokentroller) external {
        require(msg.sender == tokentroller, "Not authorized");
        tokentroller = newTokentroller;
    }

    function getTokenCounts() external view returns (uint256 pending, uint256 approved, uint256 rejected) {
        pending = tokensByStatus[TokenStatus.PENDING].length();
        approved = tokensByStatus[TokenStatus.APPROVED].length();
        rejected = tokensByStatus[TokenStatus.REJECTED].length();
    }

    function getTokenWithMetadata(address tokenAddress) external view returns (TokenWithMetadata memory) {
        Token memory token = _getToken(tokenAddress);
        MetadataValue[] memory metadata = tokenMetadata.getAllMetadata(tokenAddress);
        return TokenWithMetadata({ token: token, metadata: metadata });
    }
}
