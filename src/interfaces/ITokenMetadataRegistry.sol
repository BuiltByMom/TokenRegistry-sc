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
    event MetadataEditRejected(address indexed token, uint256 indexed editIndex, uint256 chainID, string reason);

    function addMetadataField(string calldata name) external;
    function updateMetadataField(string calldata name, bool isActive) external;
    function setMetadata(address token, uint256 chainID, string calldata field, string calldata value) external;
    function setMetadataBatch(address token, uint256 chainID, MetadataInput[] calldata metadata) external;
    function getMetadata(address token, uint256 chainID, string calldata field) external view returns (string memory);
    function getMetadataFields() external view returns (MetadataField[] memory);
    function getAllMetadata(address token, uint256 chainID) external view returns (MetadataValue[] memory);
    function isValidField(string memory field) external view returns (bool);
    function updateMetadata(address token, uint256 chainID, MetadataInput[] calldata metadata) external;
}
