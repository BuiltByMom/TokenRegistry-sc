// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokentroller.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenMetadata.sol";

contract TokenMetadata is ITokenMetadata {
    MetadataField[] public metadataFields;
    // Maps field name to field ID (array index)
    mapping(string => uint256) private nameToId;
    // Maps token => field ID => value
    mapping(address => mapping(uint256 => string)) private tokenMetadata;

    address public tokentroller;

    constructor(address _tokentroller) {
        tokentroller = _tokentroller;
        // Add logoURI as initial required field
        _addField("logoURI", true);
    }

    function _addField(string memory name, bool isRequired) private {
        require(nameToId[name] == 0, "Field already exists");
        require(bytes(name).length > 0, "Empty field name");

        uint256 fieldId = metadataFields.length;
        MetadataField memory newField = MetadataField({ name: name, isActive: true, isRequired: isRequired });

        metadataFields.push(newField);
        nameToId[name] = fieldId + 1; // Use 1-based IDs so 0 means "not found"
    }

    function addField(string calldata name) external {
        require(
            ITokentroller(tokentroller).canAddMetadataField(msg.sender, name),
            "Not authorized to add metadata field"
        );
        _addField(name, false);
        emit MetadataFieldAdded(name);
    }

    function updateField(string calldata name, bool isActive) external {
        require(
            ITokentroller(tokentroller).canUpdateMetadataField(msg.sender, name, isActive),
            "Not authorized to update metadata field"
        );

        uint256 fieldId = nameToId[name];
        require(fieldId > 0, "Field does not exist");
        uint256 index = fieldId - 1;

        metadataFields[index].isActive = isActive;
        emit MetadataFieldUpdated(name, isActive);
    }

    function _setMetadataField(address token, string calldata field, string calldata value) private returns (uint256) {
        uint256 fieldId = nameToId[field];
        require(fieldId > 0, "Field does not exist");
        uint256 index = fieldId - 1;
        require(metadataFields[index].isActive, "Invalid field");

        if (metadataFields[index].isRequired) {
            require(bytes(value).length > 0, "Required field cannot be empty");
        }

        tokenMetadata[token][index] = value;
        emit MetadataValueSet(token, field, value);
        return index;
    }

    function updateMetadata(address token, MetadataInput[] calldata metadata) external {
        require(ITokentroller(tokentroller).canUpdateMetadata(msg.sender, token), "Not authorized to update metadata");
        for (uint256 i = 0; i < metadata.length; i++) {
            _setMetadataField(token, metadata[i].field, metadata[i].value);
        }
    }

    function getMetadata(address token, string calldata field) external view returns (string memory) {
        uint256 fieldId = nameToId[field];
        if (fieldId == 0) return "";
        return tokenMetadata[token][fieldId - 1];
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
                value: tokenMetadata[token][i],
                isActive: fields[i].isActive
            });
        }

        return values;
    }

    function isValidField(string memory field) public view returns (bool) {
        uint256 fieldId = nameToId[field];
        if (fieldId == 0) return false;
        return metadataFields[fieldId - 1].isActive;
    }

    function updateTokentroller(address newTokentroller) external {
        require(msg.sender == tokentroller, "Only tokentroller can update");
        tokentroller = newTokentroller;
        emit TokentrollerUpdated(newTokentroller);
    }
}
