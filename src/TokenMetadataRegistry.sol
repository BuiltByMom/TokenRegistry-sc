// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokentroller.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenMetadataRegistry.sol";

contract TokenMetadataRegistry is ITokenMetadataRegistry {
    MetadataField[] public metadataFields; // Array to store metadata fields

    mapping(string => uint256) public fieldIndices; // Mapping to store the index of a metadata field by its name
    mapping(address => mapping(string => string)) public tokenMetadata; // Mapping to store token metadata by token address and field name

    address public tokentroller; // Address of the tokentroller

    constructor(address _tokentroller) {
        tokentroller = _tokentroller;
    }

    function addMetadataField(string calldata name) external {
        require(ITokentroller(tokentroller).canAddMetadataField(msg.sender, name), "Not authorized");
        require(bytes(name).length > 0, "Empty field name");
        require(fieldIndices[name] == 0, "Field already exists");

        MetadataField memory newField = MetadataField({ name: name, isActive: true, updatedAt: block.timestamp });

        metadataFields.push(newField);
        fieldIndices[name] = metadataFields.length;

        emit MetadataFieldAdded(name);
    }

    function updateMetadataField(string calldata name, bool isActive) external {
        require(ITokentroller(tokentroller).canUpdateMetadataField(msg.sender, name, isActive), "Not authorized");
        uint256 index = fieldIndices[name];
        require(index > 0, "Field does not exist");

        metadataFields[index - 1].isActive = isActive;
        emit MetadataFieldUpdated(name, isActive);
    }

    function setMetadata(address token, string calldata field, string calldata value) external {
        require(ITokentroller(tokentroller).canSetMetadata(msg.sender, token, field), "Not authorized");
        require(isValidField(field), "Invalid field");
        tokenMetadata[token][field] = value;
        emit MetadataValueSet(token, field, value);
    }

    function setMetadataBatch(address token, MetadataInput[] calldata metadata) external {
        for (uint256 i = 0; i < metadata.length; i++) {
            require(ITokentroller(tokentroller).canSetMetadata(msg.sender, token, metadata[i].field), "Not authorized");
            require(isValidField(metadata[i].field), "Invalid field");
            tokenMetadata[token][metadata[i].field] = metadata[i].value;
            emit MetadataValueSet(token, metadata[i].field, metadata[i].value);
        }
    }

    function updateMetadata(address token, MetadataInput[] calldata metadata) external {
        require(ITokentroller(tokentroller).canUpdateMetadata(msg.sender, token), "Not authorized");
        for (uint256 i = 0; i < metadata.length; i++) {
            require(isValidField(metadata[i].field), "Invalid field");
            tokenMetadata[token][metadata[i].field] = metadata[i].value;
            emit MetadataValueSet(token, metadata[i].field, metadata[i].value);
        }
    }

    function getMetadata(address token, string calldata field) external view returns (string memory) {
        return tokenMetadata[token][field];
    }

    function getMetadataFields() external view returns (MetadataField[] memory) {
        return metadataFields;
    }

    function getAllMetadata(address token) external view returns (MetadataValue[] memory) {
        MetadataField[] memory fields = metadataFields;
        MetadataValue[] memory values = new MetadataValue[](fields.length);

        for (uint256 i = 0; i < fields.length; i++) {
            values[i] = MetadataValue({
                field: fields[i].name,
                value: tokenMetadata[token][fields[i].name],
                isActive: fields[i].isActive
            });
        }

        return values;
    }

    function isValidField(string memory field) public view returns (bool) {
        uint256 index = fieldIndices[field];
        if (index == 0) return false;
        return metadataFields[index - 1].isActive;
    }

    function updateTokentroller(address newTokentroller) external {
        require(msg.sender == tokentroller, "Only tokentroller can update");
        tokentroller = newTokentroller;
        emit TokentrollerUpdated(newTokentroller);
    }
}
