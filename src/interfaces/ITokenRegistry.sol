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
    event TokenApproved(address indexed contractAddress, uint256 chainID);
    event TokenRejected(address indexed contractAddress, uint256 chainID);
    event TokenEditAccepted(address indexed contractAddress, uint256 indexed editIndex, uint256 chainID);
    event TokentrollerUpdated(address indexed newCouncil);
    event TokenEditRejected(address indexed contractAddress, uint256 indexed editIndex, uint256 chainID);

    function addToken(
        address _contractAddress,
        string memory _name,
        string memory _symbol,
        string memory _logoURI,
        uint8 _decimals,
        uint256 _chainID
    ) external;
    function updateToken(
        address _contractAddress,
        string memory _name,
        string memory _symbol,
        string memory _logoURI,
        uint8 _decimals,
        uint256 _chainID
    ) external;
    function acceptTokenEdit(address _contractAddress, uint256 _editIndex, uint256 _chainID) external;
    function rejectTokenEdit(address _contractAddress, uint256 _editIndex, uint256 _chainID) external;
    function fastTrackToken(uint256 _chainID, address _contractAddress) external;
    function rejectToken(uint256 _chainID, address _contractAddress) external;
    function updateTokentroller(address _newTokentroller) external;
    function addTokenWithMetadata(
        address _contractAddress,
        string memory _name,
        string memory _symbol,
        string memory _logoURI,
        uint8 _decimals,
        uint256 _chainID,
        MetadataInput[] calldata metadata
    ) external;
    function proposeTokenAndMetadataEdit(
        address _contractAddress,
        string memory _name,
        string memory _symbol,
        string memory _logoURI,
        uint8 _decimals,
        uint256 _chainID,
        MetadataInput[] calldata metadataUpdates
    ) external;

    function tokenCount(uint256 _chainID) external view returns (uint256);
    function getTokenCounts(
        uint256 _chainID
    ) external view returns (uint256 pending, uint256 approved, uint256 rejected);
    function listAllEdits(
        uint256 _chainID,
        uint256 _initialIndex,
        uint256 _size
    ) external view returns (TokenEdit[] memory edits_, uint256 finalIndex_, bool hasMore_);
    function tokensWithEditsLength(uint256 _chainID) external view returns (uint256);
    function getTokensWithEdits(uint256 _chainID, uint256 _index) external view returns (address);
}
