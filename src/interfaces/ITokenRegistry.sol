// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ISharedTypes.sol";

interface ITokenRegistry {
    struct Token {
        address contractAddress;
        string name; // Read from ERC20
        string symbol; // Read from ERC20
        uint8 decimals; // Read from ERC20
        string logoURI;
        TokenStatus status;
        MetadataValue[] metadata; // Optional metadata
    }

    event TokenAdded(address indexed contractAddress, address indexed submitter);
    event TokenApproved(address indexed contractAddress);
    event TokenRejected(address indexed contractAddress, string reason);
    event TokentrollerUpdated(address indexed newTokentroller);

    function addToken(address contractAddress, MetadataInput[] calldata metadata) external;
    function approveToken(address contractAddress) external;
    function rejectToken(address contractAddress, string calldata reason) external;
    function getToken(address contractAddress) external view returns (Token memory);
    function getToken(address contractAddress, bool includeMetadata) external view returns (Token memory);
    function getTokens(address[] calldata contractAddresses) external view returns (Token[] memory);
    function getTokens(
        address[] calldata contractAddresses,
        bool includeMetadata
    ) external view returns (Token[] memory);
    function listTokens(
        uint256 offset,
        uint256 limit,
        TokenStatus status
    ) external view returns (Token[] memory tokens, uint256 total);
    function listTokens(
        uint256 offset,
        uint256 limit,
        TokenStatus status,
        bool includeMetadata
    ) external view returns (Token[] memory tokens, uint256 total);
    function getTokenCounts() external view returns (uint256 pending, uint256 approved, uint256 rejected);
    function updateTokentroller(address newTokentroller) external;
    function tokenStatus(address contractAddress) external view returns (TokenStatus);
}
