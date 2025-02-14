// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ITokentroller.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenMetadata.sol";

/**********************************************************************************************
 * @title TokenMetadata
 * @dev A contract that manages metadata fields and values for tokens.
 * This contract allows for flexible metadata management with support for
 * required fields, field activation/deactivation, and value updates.
 *********************************************************************************************/
contract TokenMetadata is ITokenMetadata {
    MetadataField[] public metadataFields;
    // Maps field name to field ID (array index)
    mapping(string => uint256) private nameToId;
    // Maps token => field ID => value
    mapping(address => mapping(uint256 => string)) private tokenMetadata;

    address public tokentroller;

    /**********************************************************************************************
     * @dev Constructor for the TokenMetadata contract
     * @param _tokentroller The address of the tokentroller contract
     * @notice Initializes the contract with the tokentroller address and adds logoURI as required field
     *********************************************************************************************/
    constructor(address _tokentroller) {
        require(_tokentroller != address(0), "TokenMetadata: tokentroller cannot be zero address");
        tokentroller = _tokentroller;
        // Add logoURI as initial required field
        _addField("logoURI", true);
    }

    /**********************************************************************************************
     *  __  __       _        _
     * |  \/  |_   _| |_ __ _| |_ ___  _ __ ___
     * | |\/| | | | | __/ _` | __/ _ \| '__/ __|
     * | |  | | |_| | || (_| | || (_) | |  \__ \
     * |_|  |_|\__,_|\__\__,_|\__\___/|_|  |___/
     *
     * @dev These functions are designed to alter the state of the metadata.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Internal function to add a new metadata field
     * @param name The name of the field to add
     * @param isRequired Whether the field is required for all tokens
     * @notice Validates field name and adds it to the metadata fields array
     *********************************************************************************************/
    function _addField(string memory name, bool isRequired) private {
        require(nameToId[name] == 0, "Field already exists");
        require(bytes(name).length > 0, "Empty field name");

        uint256 fieldId = metadataFields.length;
        MetadataField memory newField = MetadataField({ name: name, isActive: true, isRequired: isRequired });

        metadataFields.push(newField);
        nameToId[name] = fieldId + 1; // Use 1-based IDs so 0 means "not found"
    }

    /**********************************************************************************************
     * @dev Adds a new required metadata field
     * @param name The name of the field to add
     * @param isRequired Whether the field is required for all tokens
     * @notice This function can only be called by authorized addresses
     * @notice Emits a MetadataFieldAdded event on success
     *********************************************************************************************/
    function addField(string calldata name, bool isRequired) external {
        require(
            ITokentroller(tokentroller).canAddMetadataField(msg.sender, name),
            "Not authorized to add metadata field"
        );
        _addField(name, isRequired);
        emit MetadataFieldAdded(name);
    }

    /**********************************************************************************************
     * @dev Adds a new optional metadata field
     * @param name The name of the field to add
     * @notice This function can only be called by authorized addresses
     * @notice The field will be added as non-required
     * @notice Emits a MetadataFieldAdded event on success
     *********************************************************************************************/
    function addField(string calldata name) external {
        require(
            ITokentroller(tokentroller).canAddMetadataField(msg.sender, name),
            "Not authorized to add metadata field"
        );
        _addField(name, false);
        emit MetadataFieldAdded(name);
    }

    /**********************************************************************************************
     * @dev Updates a metadata field's properties
     * @param name The name of the field to update
     * @param isActive Whether the field should be active
     * @param isRequired Whether the field should be required
     * @notice This function can only be called by authorized addresses
     * @notice Emits a MetadataFieldUpdated event on success
     *********************************************************************************************/
    function updateField(string calldata name, bool isActive, bool isRequired) external {
        require(
            ITokentroller(tokentroller).canUpdateMetadataField(msg.sender, name, isActive, isRequired),
            "Not authorized to update metadata field"
        );

        uint256 fieldId = nameToId[name];
        require(fieldId > 0, "Field does not exist");
        uint256 index = fieldId - 1;

        metadataFields[index].isActive = isActive;
        metadataFields[index].isRequired = isRequired;
        emit MetadataFieldUpdated(name, isActive, isRequired);
    }

    /**********************************************************************************************
     * @dev Internal function to set a metadata field value
     * @param token The address of the token
     * @param field The name of the field to set
     * @param value The value to set for the field
     * @notice Validates field existence and requirements
     * @notice Emits a MetadataValueSet event on success
     * @return uint256 The index of the updated field
     *********************************************************************************************/
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

    /**********************************************************************************************
     * @dev Updates metadata values for a token
     * @param token The address of the token
     * @param metadata Array of metadata fields and values to update
     * @notice This function can only be called by authorized addresses
     * @notice Updates multiple metadata fields in a single transaction
     *********************************************************************************************/
    function updateMetadata(address token, MetadataInput[] calldata metadata) external {
        require(ITokentroller(tokentroller).canUpdateMetadata(msg.sender, token), "Not authorized to update metadata");
        for (uint256 i = 0; i < metadata.length; i++) {
            _setMetadataField(token, metadata[i].field, metadata[i].value);
        }
    }

    /**********************************************************************************************
     *     _
     *    / \   ___ ___ ___  ___ ___  ___  _ __ ___
     *   / _ \ / __/ __/ _ \/ __/ __|/ _ \| '__/ __|
     *  / ___ \ (_| (_|  __/\__ \__ \ (_) | |  \__ \
     * /_/   \_\___\___\___||___/___/\___/|_|  |___/
     *
     * @dev These functions are for the public to get information about the metadata.
     * They do not require any special permissions or access control and are read-only.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Gets a specific metadata value for a token
     * @param token The address of the token
     * @param field The name of the field to get
     * @return string The value of the metadata field
     * @notice Returns empty string if field doesn't exist
     *********************************************************************************************/
    function getMetadata(address token, string calldata field) external view returns (string memory) {
        uint256 fieldId = nameToId[field];
        if (fieldId == 0) return "";
        return tokenMetadata[token][fieldId - 1];
    }

    /**********************************************************************************************
     * @dev Gets all metadata fields
     * @return MetadataField[] Array of all metadata fields
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function getMetadataFields() external view returns (MetadataField[] memory) {
        return metadataFields;
    }

    /**********************************************************************************************
     * @dev Gets all metadata values for a token
     * @param token The address of the token
     * @return MetadataValue[] Array of all metadata values for the token
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
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

    /**********************************************************************************************
     * @dev Gets information about a specific metadata field
     * @param field The name of the field to get
     * @return MetadataField The field information
     * @notice Returns empty field if the requested field doesn't exist
     *********************************************************************************************/
    function getField(string calldata field) public view returns (MetadataField memory) {
        uint256 fieldId = nameToId[field];
        if (fieldId == 0) return MetadataField("", false, false);
        return metadataFields[fieldId - 1];
    }

    /**********************************************************************************************
     *  _____     _              _             _ _
     * |_   _|__ | | _____ _ __ | |_ _ __ ___ | | | ___ _ __
     *   | |/ _ \| |/ / _ \ '_ \| __| '__/ _ \| | |/ _ \ '__|
     *   | | (_) |   <  __/ | | | |_| | | (_) | | |  __/ |
     *   |_|\___/|_|\_\___|_| |_|\__|_|  \___/|_|_|\___|_|
     *
     * @dev All the functions below are to manage the metadata with tokentroller.
     * All the verifications are handled by the Tokentroller contract, which can be upgraded at
     * any time by the owner of the contract.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Updates the tokentroller address
     * @param newTokentroller The address of the new tokentroller
     * @notice This function can only be called by the current tokentroller
     * @notice Emits a TokentrollerUpdated event on success
     *********************************************************************************************/
    function updateTokentroller(address newTokentroller) external {
        require(msg.sender == tokentroller, "Only tokentroller can update");
        require(newTokentroller != address(0), "TokenMetadata: tokentroller cannot be zero address");
        tokentroller = newTokentroller;
        emit TokentrollerUpdated(newTokentroller);
    }
}
