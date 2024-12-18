// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISharedTypes.sol";

interface ITokenMetadataRegistry {
    struct EditParams {
        uint256 chainID;
        uint256 initialIndex;
        uint256 size;
        uint256 totalEdits;
    }

    struct MetadataEditProposal {
        address submitter;
        MetadataInput[] updates;
        uint256 chainID;
        uint256 timestamp;
    }

    struct MetadataEditInfo {
        address token;
        address submitter;
        MetadataInput[] updates;
        uint256 chainID;
        uint256 editIndex;
        uint256 timestamp;
    }

    struct MetadataField {
        string name;
        bool isActive;
        uint256 updatedAt;
    }

    struct MetadataValue {
        string field;
        string value;
        bool isActive;
    }

    struct EditProposalDetails {
        address submitter;
        MetadataInput[] updates;
        uint256 chainID;
        uint256 timestamp;
    }

    event MetadataFieldAdded(string name);
    event MetadataFieldUpdated(string name, bool isActive);
    event MetadataValueSet(address indexed token, uint256 indexed chainID, string field, string value);

    event TokentrollerUpdated(address indexed newTokentroller);

    event MetadataEditProposed(
        address indexed token,
        uint256 indexed chainID,
        address submitter,
        MetadataInput[] updates
    );
    event MetadataEditAccepted(address indexed token, uint256 indexed editIndex, uint256 chainID);
    event MetadataEditRejected(address indexed token, uint256 indexed editIndex, uint256 chainID);

    function addMetadataField(string calldata name) external;
    function updateMetadataField(string calldata name, bool isActive) external;
    function setMetadata(address token, uint256 chainID, string calldata field, string calldata value) external;
    function setMetadataBatch(address token, uint256 chainID, MetadataInput[] calldata metadata) external;
    function getMetadata(address token, uint256 chainID, string calldata field) external view returns (string memory);
    function getMetadataFields() external view returns (MetadataField[] memory);
    function getAllMetadata(address token, uint256 chainID) external view returns (MetadataValue[] memory);
    function proposeMetadataEdit(address token, uint256 chainID, MetadataInput[] calldata updates) external;
    function acceptMetadataEdit(address token, uint256 chainID, uint256 editIndex) external;
    function rejectMetadataEdit(address token, uint256 chainID, uint256 editIndex) external;
    function getEditProposal(
        uint256 chainID,
        address token,
        uint256 editIndex
    ) external view returns (EditProposalDetails memory);
    function tokensMetadataWithEditsLength(uint256 chainID) external view returns (uint256);
    function getTokensMetadataWithEdits(uint256 chainID, uint256 index) external view returns (address);
}
