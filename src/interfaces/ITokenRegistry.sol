// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISharedTypes.sol";
interface ITokenRegistry {
    struct Token {
        address contractAddress;
        address submitter;
        string name;
        string logoURI;
        string symbol;
        uint8 decimals;
    }

    event TokenAdded(address indexed contractAddress, string name, string symbol, string logoURI, uint8 decimals);
    event TokenApproved(address indexed contractAddress);
    event TokenRejected(address indexed contractAddress, string reason);
    event TokentrollerUpdated(address indexed newTokentroller);

    function addToken(
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals
    ) external;

    function approveToken(address contractAddress) external;

    function rejectToken(address contractAddress, string calldata reason) external;

    function listTokens(
        uint256 offset,
        uint256 limit,
        TokenStatus status
    ) external view returns (Token[] memory tokens_, uint256 total);

    function tokenCount() external view returns (uint256);
    function getTokenCounts() external view returns (uint256 pending, uint256 approved, uint256 rejected);

    function updateTokentroller(address newTokentroller) external;

    function updateToken(
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals
    ) external;
}
