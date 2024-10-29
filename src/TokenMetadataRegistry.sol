// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TokenMetadataRegistry {
    address public tokentroller;

    // Metadata field definition
    struct MetadataField {
        string name;      // Name of the field (e.g., "website", "twitter", "github")
        bool isRequired;  // Whether this field is required
        bool isActive;    // Whether this field is currently active
    }

    // Storage
    mapping(uint256 => MetadataField[]) public metadataFields;           // Array of metadata fields per chain
    mapping(uint256 => mapping(string => uint256)) public fieldIndices;  // Field name to index mapping
    mapping(uint256 => mapping(address => mapping(string => string))) public tokenMetadata;  // Token metadata values

    // Events
    event MetadataFieldAdded(uint256 indexed chainId, string name, bool isRequired);
    event MetadataFieldUpdated(uint256 indexed chainId, string name, bool isActive);
    event MetadataValueSet(uint256 indexed chainId, address indexed token, string field, string value);
    event TokentrollerUpdated(address indexed newTokentroller);

    modifier onlyTokentroller() {
        require(msg.sender == tokentroller, "Only tokentroller can call");
        _;
    }

    constructor(address _tokentroller) {
        tokentroller = _tokentroller;
    }

    // Admin functions
    function addMetadataField(
        uint256 chainId,
        string calldata name,
        bool isRequired
    ) external onlyTokentroller {
        require(bytes(name).length > 0, "Empty field name");
        require(fieldIndices[chainId][name] == 0, "Field already exists");

        MetadataField memory newField = MetadataField({
            name: name,
            isRequired: isRequired,
            isActive: true
        });

        metadataFields[chainId].push(newField);
        fieldIndices[chainId][name] = metadataFields[chainId].length;

        emit MetadataFieldAdded(chainId, name, isRequired);
    }

    function updateMetadataField(
        uint256 chainId,
        string calldata name,
        bool isActive
    ) external onlyTokentroller {
        uint256 index = fieldIndices[chainId][name];
        require(index > 0, "Field does not exist");
        
        metadataFields[chainId][index - 1].isActive = isActive;
        emit MetadataFieldUpdated(chainId, name, isActive);
    }

    // Metadata setter
    function setMetadata(
        uint256 chainId,
        address token,
        string calldata field,
        string calldata value
    ) external {
        require(_isValidField(chainId, field), "Invalid field");
        tokenMetadata[chainId][token][field] = value;
        emit MetadataValueSet(chainId, token, field, value);
    }

    // Getters
    function getMetadata(
        uint256 chainId,
        address token,
        string calldata field
    ) external view returns (string memory) {
        return tokenMetadata[chainId][token][field];
    }

    function getMetadataFields(uint256 chainId) external view returns (MetadataField[] memory) {
        return metadataFields[chainId];
    }

    // Internal functions
    function _isValidField(
        uint256 chainId,
        string memory field
    ) internal view returns (bool) {
        uint256 index = fieldIndices[chainId][field];
        if (index == 0) return false;
        
        return metadataFields[chainId][index - 1].isActive;
    }

    // Admin functions
    function updateTokentroller(address _newTokentroller) external onlyTokentroller {
        require(_newTokentroller != address(0), "Invalid tokentroller address");
        tokentroller = _newTokentroller;
        emit TokentrollerUpdated(_newTokentroller);
    }
}