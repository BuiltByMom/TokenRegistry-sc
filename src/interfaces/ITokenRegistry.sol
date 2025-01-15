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
        uint256 chainID;
    }

    event TokenAdded(
        address indexed contractAddress,
        string name,
        string symbol,
        string logoURI,
        uint8 decimals,
        uint256 chainID
    );
    event TokenApproved(address indexed contractAddress, uint256 indexed chainID);
    event TokenRejected(address indexed contractAddress, uint256 indexed chainID, string reason);
    event TokentrollerUpdated(address indexed newTokentroller);

    function addToken(
        uint256 chainID,
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals
    ) external;

    function approveToken(uint256 chainID, address contractAddress) external;

    function rejectToken(uint256 chainID, address contractAddress, string calldata reason) external;

    function listTokens(
        uint256 chainID,
        uint256 offset,
        uint256 limit,
        TokenStatus status
    ) external view returns (Token[] memory tokens_, uint256 total);

    function tokenCount(uint256 _chainID) external view returns (uint256);
    function getTokenCounts(
        uint256 chainID
    ) external view returns (uint256 pending, uint256 approved, uint256 rejected);

    function updateTokentroller(address newTokentroller) external;

    function updateToken(
        uint256 chainID,
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals
    ) external;
}
