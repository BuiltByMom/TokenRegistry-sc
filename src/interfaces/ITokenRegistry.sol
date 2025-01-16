// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISharedTypes.sol";

interface ITokenRegistry {
    struct Token {
        address contractAddress;
        string name; // Read from ERC20
        string logoURI; // Stored in registry
        string symbol; // Read from ERC20
        uint8 decimals; // Read from ERC20
    }

    event TokenAdded(address indexed contractAddress, address submitter);
    event TokenApproved(address indexed contractAddress);
    event TokenRejected(address indexed contractAddress, string reason);
    event TokenUpdated(address indexed contractAddress, string logoURI);
    event TokentrollerUpdated(address indexed newTokentroller);

    function addToken(address contractAddress, string calldata logoURI) external;
    function approveToken(address contractAddress) external;
    function rejectToken(address contractAddress, string calldata reason) external;
    function updateToken(address contractAddress, string calldata logoURI) external;
    function getToken(address contractAddress) external view returns (Token memory);
    function listTokens(
        uint256 offset,
        uint256 limit,
        TokenStatus status
    ) external view returns (Token[] memory tokens, uint256 total);
    function getTokenCounts() external view returns (uint256 pending, uint256 approved, uint256 rejected);
    function updateTokentroller(address newTokentroller) external;
}
