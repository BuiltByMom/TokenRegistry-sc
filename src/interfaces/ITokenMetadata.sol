// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISharedTypes.sol";

interface ITokenMetadata {
    struct EditParams {
        uint256 initialIndex;
        uint256 size;
        uint256 totalEdits;
    }
    struct MetadataField {
        string name;
        bool isActive;
        bool isRequired;
    }

    event MetadataFieldAdded(string name);
    event MetadataFieldUpdated(string name, bool isActive, bool isRequired);
    event MetadataValueSet(address indexed token, string field, string value);

    event TokentrollerUpdated(address indexed newTokentroller);

    event MetadataEditProposed(address indexed token, address submitter, MetadataInput[] updates);
    event MetadataEditAccepted(address indexed token, uint256 indexed editIndex);
    event MetadataEditRejected(address indexed token, uint256 indexed editIndex, string reason);

    function addField(string calldata name, bool isRequired) external;
    function addField(string calldata name) external;
    function updateField(string calldata name, bool isActive, bool isRequired) external;
    function getMetadata(address token, string calldata field) external view returns (string memory);
    function getMetadataFields() external view returns (MetadataField[] memory);
    function getAllMetadata(address token) external view returns (MetadataValue[] memory);
    function getField(string calldata field) external view returns (MetadataField memory);
    function updateMetadata(address token, MetadataInput[] calldata metadata) external;
}
