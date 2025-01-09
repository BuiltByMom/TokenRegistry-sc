// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ITokenMetadataRegistry.sol";

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

    struct TokenEdit {
        address contractAddress;
        address submitter;
        string name;
        string logoURI;
        string symbol;
        uint8 decimals;
        uint256 chainID;
        uint256 editIndex;
    }

    struct EditParams {
        uint256 chainID;
        uint256 initialIndex;
        uint256 size;
        uint256 totalEdits;
    }

    event TokenAdded(
        address indexed contractAddress,
        string name,
        string symbol,
        string logoURI,
        uint8 decimals,
        uint256 chainID
    );
    event UpdateSuggested(
        address indexed contractAddress,
        string name,
        string symbol,
        string logoURI,
        uint8 decimals,
        uint256 chainID
    );
    event TokenApproved(address indexed contractAddress, uint256 indexed chainID);
    event TokenRejected(address indexed contractAddress, uint256 indexed chainID, string reason);
    event TokenEditAccepted(address indexed contractAddress, uint256 indexed editIndex, uint256 indexed chainID);
    event TokenEditRejected(
        address indexed contractAddress,
        uint256 indexed editIndex,
        uint256 indexed chainID,
        string reason
    );
    event TokentrollerUpdated(address indexed newCouncil);

    function addToken(
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals,
        uint256 chainID
    ) external;
    function proposeTokenEdit(
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals,
        uint256 chainID
    ) external;
    function acceptTokenEdit(address contractAddress, uint256 editIndex, uint256 chainID) external;
    function rejectTokenEdit(
        address contractAddress,
        uint256 editIndex,
        uint256 chainID,
        string calldata reason
    ) external;
    function approveToken(uint256 chainID, address contractAddress) external;
    function rejectToken(uint256 chainID, address contractAddress, string calldata reason) external;
    function updateTokentroller(address newTokentroller) external;
    function addTokenWithMetadata(
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals,
        uint256 chainID,
        MetadataInput[] calldata metadata
    ) external;
    function proposeTokenAndMetadataEdit(
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals,
        uint256 chainID,
        MetadataInput[] calldata metadataUpdates
    ) external;

    function tokenCount(uint256 _chainID) external view returns (uint256);
    function getTokenCounts(
        uint256 chainID
    ) external view returns (uint256 pending, uint256 approved, uint256 rejected);
    function listAllEdits(
        uint256 chainID,
        uint256 initialIndex,
        uint256 size
    ) external view returns (TokenEdit[] memory edits, uint256 finalIndex, bool hasMore);
    function tokensWithEditsLength(uint256 chainID) external view returns (uint256);
    function getTokensWithEdits(uint256 chainID, uint256 index) external view returns (address);
}
