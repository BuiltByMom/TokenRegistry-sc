// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokentroller.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenMetadataRegistry.sol";

contract TokenMetadataRegistry is ITokenMetadataRegistry {
    MetadataField[] public metadataFields; // Array to store metadata fields

    mapping(string => uint256) public fieldIndices; // Mapping to store the index of a metadata field by its name
    mapping(uint256 => mapping(address => mapping(string => string))) public tokenMetadata; // Mapping to store token metadata by chainID, token address, and field name

    mapping(uint256 => mapping(address => mapping(uint256 => MetadataEditProposal))) public editsOnTokens; // Mapping to store edit proposals by chainID, token address, and edit index
    mapping(uint256 => mapping(address => uint256)) public editCount; // Mapping to store the count of edits for a token by chainID and token address
    mapping(uint256 => address[]) public tokensMetadataWithEdits; // Array to store the addresses of tokens with edits by chainID

    address public tokentroller; // Address of the tokentroller

    /**********************************************************************************************
     * @dev Constructor for the TokenMetadataRegistry contract
     * @param _tokentroller The address of the tokentroller contract that manages token approvals
     * @notice Initializes the contract with the tokentroller address
     * @notice The tokentroller is responsible for managing token approvals and rejections
     * @notice This constructor sets up the initial state for the token metadata registry
     *********************************************************************************************/
    constructor(address _tokentroller) {
        tokentroller = _tokentroller;
    }

    /**********************************************************************************************
     *  __  __       _        _
     * |  \/  |_   _| |_ __ _| |_ ___  _ __ ___
     * | |\/| | | | | __/ _` | __/ _ \| '__/ __|
     * | |  | | |_| | || (_| | || (_) | |  \__ \
     * |_|  |_|\__,_|\__\__,_|\__\___/|_|  |___/
     *
     * @dev These functions are designed to alter the state of the metadata registry.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Adds a new metadata field to the registry
     * @param _name The name of the metadata field
     * @param _isActive The status of the metadata field
     * @param _updatedAt The timestamp of the last update
     * @notice Anyone can call this function to submit a new metadata field for consideration
     * @notice The metadata field is initially set to a pending status
     * @notice Emits a MetadataFieldAdded event upon successful addition
     * @notice Requires the metadata field to not already exist and have a valid name
     * @notice Checks with the Tokentroller if the metadata field can be added
     *********************************************************************************************/
    function addMetadataField(string calldata name) external {
        require(ITokentroller(tokentroller).canAddMetadataField(msg.sender, name), "Not authorized");
        require(bytes(name).length > 0, "Empty field name");
        require(fieldIndices[name] == 0, "Field already exists");

        MetadataField memory newField = MetadataField({ name: name, isActive: true, updatedAt: block.timestamp });

        metadataFields.push(newField);
        fieldIndices[name] = metadataFields.length;

        emit MetadataFieldAdded(name);
    }

    /**********************************************************************************************
     * @dev Allows to deprecate a metadata field
     * @param _name The name of the metadata field
     * @param _isActive The new status of the metadata field
     * @notice Emits a MetadataFieldUpdated event upon successful update
     * @notice Requires the metadata field to exist and have a valid name
     * @notice Checks with the Tokentroller if the metadata field can be updated
     *********************************************************************************************/
    function updateMetadataField(string calldata name, bool isActive) external {
        require(ITokentroller(tokentroller).canUpdateMetadataField(msg.sender, name, isActive), "Not authorized");
        uint256 index = fieldIndices[name];
        require(index > 0, "Field does not exist");

        metadataFields[index - 1].isActive = isActive;
        emit MetadataFieldUpdated(name, isActive);
    }

    /**********************************************************************************************
     * @dev Allows to set the metadata of a token
     * @param _token The address of the token
     * @param _chainID The chain ID of the token
     * @param _field The name of the metadata field
     * @param _value The value of the metadata field
     * @notice Emits a MetadataValueSet event upon successful update
     * @notice Requires the metadata field to exist and have a valid name
     * @notice Checks with the Tokentroller if the metadata field can be updated
     *********************************************************************************************/
    function setMetadata(address token, uint256 chainID, string calldata field, string calldata value) external {
        require(ITokentroller(tokentroller).canSetMetadata(msg.sender, token, chainID, field), "Not authorized");
        require(_isValidField(field), "Invalid field");
        tokenMetadata[chainID][token][field] = value;
        emit MetadataValueSet(token, chainID, field, value);
    }

    /**********************************************************************************************
     * @dev Allows to set the metadata of a token in batch
     * @param _token The address of the token
     * @param _chainID The chain ID of the token
     * @param _metadata An array of MetadataInput structs
     * @notice Emits a MetadataValueSet event upon successful update
     * @notice Requires the metadata field to exist and have a valid name
     * @notice Checks with the Tokentroller if the metadata field can be updated
     *********************************************************************************************/
    function setMetadataBatch(address token, uint256 chainID, MetadataInput[] calldata metadata) external {
        require(ITokentroller(tokentroller).canSetMetadata(msg.sender, token, chainID, ""), "Not authorized");

        for (uint256 i = 0; i < metadata.length; i++) {
            require(_isValidField(metadata[i].field), "Invalid field");
            tokenMetadata[chainID][token][metadata[i].field] = metadata[i].value;
            emit MetadataValueSet(token, chainID, metadata[i].field, metadata[i].value);
        }
    }

    /**********************************************************************************************
     * @dev Allows to propose a metadata edit for a token
     * @param _token The address of the token
     * @param _chainID The chain ID of the token
     * @param _updates An array of MetadataInput structs
     * @notice Emits a MetadataEditProposed event upon successful update
     * @notice Requires the metadata field to exist and have a valid name
     * @notice Checks with the Tokentroller if the metadata field can be updated
     *********************************************************************************************/
    function proposeMetadataEdit(address token, uint256 chainID, MetadataInput[] calldata updates) external {
        require(
            ITokentroller(tokentroller).canProposeMetadataEdit(msg.sender, token, chainID, updates),
            "Not authorized"
        );
        require(updates.length > 0, "No updates provided");

        // Validate all fields
        for (uint256 i = 0; i < updates.length; i++) {
            require(_isValidField(updates[i].field), "Invalid field");
        }

        uint256 newIndex = ++editCount[chainID][token];

        // Add to tokensMetadataWithEdits if this is the first edit
        if (newIndex == 1) {
            tokensMetadataWithEdits[chainID].push(token);
        }

        // Store the edit proposal
        MetadataEditProposal storage proposal = editsOnTokens[chainID][token][newIndex];
        proposal.submitter = msg.sender;
        proposal.chainID = chainID;
        proposal.timestamp = block.timestamp;

        // Store updates
        for (uint256 i = 0; i < updates.length; i++) {
            proposal.updates.push(updates[i]);
        }

        emit MetadataEditProposed(token, chainID, msg.sender, updates);
    }

    /**********************************************************************************************
     * @dev Allows to accept a metadata edit for a token
     * @param _token The address of the token
     * @param _chainID The chain ID of the token
     * @param _editIndex The index of the edit proposal
     * @notice Emits a MetadataEditAccepted event upon successful update
     * @notice Requires the edit proposal to exist and have a valid index
     * @notice Checks with the Tokentroller if the edit proposal can be accepted
     *********************************************************************************************/
    function acceptMetadataEdit(address token, uint256 chainID, uint256 editIndex) external {
        require(
            ITokentroller(tokentroller).canAcceptMetadataEdit(msg.sender, token, chainID, editIndex),
            "Not authorized"
        );
        require(editIndex <= editCount[chainID][token], "Invalid edit index");
        require(editCount[chainID][token] > 0, "No edit exists");

        MetadataEditProposal storage edit = editsOnTokens[chainID][token][editIndex];

        // Apply all updates
        for (uint256 i = 0; i < edit.updates.length; i++) {
            tokenMetadata[chainID][token][edit.updates[i].field] = edit.updates[i].value;
            emit MetadataValueSet(token, chainID, edit.updates[i].field, edit.updates[i].value);
        }

        // Clear all edits and remove from tracking
        for (uint256 i = 1; i <= editCount[chainID][token]; i++) {
            delete editsOnTokens[chainID][token][i];
        }
        editCount[chainID][token] = 0;

        _removeTokenFromEdits(chainID, token);

        emit MetadataEditAccepted(token, editIndex, chainID);
    }

    /**********************************************************************************************
     * @dev Allows to reject a metadata edit for a token
     * @param _token The address of the token
     * @param _chainID The chain ID of the token
     * @param _editIndex The index of the edit proposal
     * @param _reason The reason for rejecting the edit
     * @notice Emits a MetadataEditRejected event upon successful update
     * @notice Requires the edit proposal to exist and have a valid index
     * @notice Checks with the Tokentroller if the edit proposal can be rejected
     *********************************************************************************************/
    function rejectMetadataEdit(address token, uint256 chainID, uint256 editIndex, string calldata reason) external {
        require(
            ITokentroller(tokentroller).canRejectTokenEdit(msg.sender, token, chainID, editIndex),
            "Not authorized"
        );
        require(editIndex <= editCount[chainID][token], "Invalid edit index");
        require(editCount[chainID][token] > 0, "No edit exists");

        // Clear the rejected edit
        delete editsOnTokens[chainID][token][editIndex];
        editCount[chainID][token]--;

        // If no more edits, remove from tracking
        if (editCount[chainID][token] == 0) {
            _removeTokenFromEdits(chainID, token);
        }

        emit MetadataEditRejected(token, editIndex, chainID, reason);
    }

    /**********************************************************************************************
     * @dev Internal function to remove a token from the list of tokens with edits
     * @param chainID The chain ID of the token
     * @param token The address of the token
     *********************************************************************************************/
    function _removeTokenFromEdits(uint256 chainID, address token) internal {
        address[] storage edits = tokensMetadataWithEdits[chainID];
        for (uint256 i = 0; i < edits.length; i++) {
            if (edits[i] == token) {
                edits[i] = edits[edits.length - 1];
                edits.pop();
                break;
            }
        }
    }

    /**********************************************************************************************
     *     _
     *    / \   ___ ___ ___  ___ ___  ___  _ __ ___
     *   / _ \ / __/ __/ _ \/ __/ __|/ _ \| '__/ __|
     *  / ___ \ (_| (_|  __/\__ \__ \ (_) | |  \__ \
     * /_/   \_\___\___\___||___/___/\___/|_|  |___/
     *
     * @dev These functions are for the public to get information about the metadata in the registry.
     * They do not require any special permissions or access control and are read-only.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Retrieves the metadata of a token
     * @param _token The address of the token
     * @param _chainID The chain ID of the token
     * @param _field The name of the metadata field
     * @return string memory The value of the metadata field
     *********************************************************************************************/
    function getMetadata(address token, uint256 chainID, string calldata field) external view returns (string memory) {
        return tokenMetadata[chainID][token][field];
    }

    /**********************************************************************************************
     * @dev Retrieves the metadata fields
     * @return MetadataField[] memory The metadata fields
     *********************************************************************************************/
    function getMetadataFields() external view returns (MetadataField[] memory) {
        return metadataFields;
    }

    /**********************************************************************************************
     * @dev Retrieves all the metadata of a token
     * @param _token The address of the token
     * @param _chainID The chain ID of the token
     * @return MetadataValue[] memory The metadata values
     *********************************************************************************************/
    function getAllMetadata(address token, uint256 chainID) external view returns (MetadataValue[] memory) {
        MetadataField[] memory fields = metadataFields;
        MetadataValue[] memory values = new MetadataValue[](fields.length);

        for (uint256 i = 0; i < fields.length; i++) {
            values[i] = MetadataValue({
                field: fields[i].name,
                value: tokenMetadata[chainID][token][fields[i].name],
                isActive: fields[i].isActive
            });
        }

        return values;
    }

    /**********************************************************************************************
     * @dev Allows to list all the metadata edits for a token
     * @param chainID The chain ID of the token
     * @param initialIndex The index of the first edit to return
     * @param size The number of edits to return
     * @return MetadataEditInfo[] memory The metadata edits
     *********************************************************************************************/
    function listAllEdits(
        uint256 chainID,
        uint256 initialIndex,
        uint256 size
    ) external view returns (MetadataEditInfo[] memory edits_, uint256 finalIndex_, bool hasMore_) {
        require(size > 0, "Size must be greater than zero");

        // Count total edits
        uint256 totalEdits = 0;
        for (uint256 i = 0; i < tokensMetadataWithEdits[chainID].length; i++) {
            totalEdits += editCount[chainID][tokensMetadataWithEdits[chainID][i]];
        }

        if (totalEdits == 0 || initialIndex >= totalEdits) {
            return (new MetadataEditInfo[](0), 0, false);
        }

        uint256 arraySize = size > (totalEdits - initialIndex) ? (totalEdits - initialIndex) : size;
        edits_ = new MetadataEditInfo[](arraySize);

        EditParams memory params = EditParams({
            chainID: chainID,
            initialIndex: initialIndex,
            size: arraySize,
            totalEdits: totalEdits
        });

        (finalIndex_, hasMore_) = _getEdits(edits_, params);
    }

    /**********************************************************************************************
     * @dev Allows to get the number of tokens with edits
     * @param chainID The chain ID of the token
     * @return uint256 The number of tokens with edits
     *********************************************************************************************/
    function tokensMetadataWithEditsLength(uint256 chainID) public view returns (uint256) {
        return tokensMetadataWithEdits[chainID].length;
    }

    /**********************************************************************************************
     * @dev Allows to get the address of a token with edits
     * @param chainID The chain ID of the token
     * @param index The index of the token
     * @return address The address of the token
     *********************************************************************************************/
    function getTokensMetadataWithEdits(uint256 chainID, uint256 index) public view returns (address) {
        return tokensMetadataWithEdits[chainID][index];
    }

    /**********************************************************************************************
     * @dev Allows to get the details of a metadata edit proposal
     * @param chainID The chain ID of the token
     * @param token The address of the token
     * @param editIndex The index of the edit proposal
     * @return EditProposalDetails memory The details of the edit proposal
     *********************************************************************************************/
    function getEditProposal(
        uint256 chainID,
        address token,
        uint256 editIndex
    ) external view returns (EditProposalDetails memory) {
        MetadataEditProposal storage proposal = editsOnTokens[chainID][token][editIndex];
        return
            EditProposalDetails({
                submitter: proposal.submitter,
                updates: proposal.updates,
                chainID: proposal.chainID,
                timestamp: proposal.timestamp
            });
    }

    /**********************************************************************************************
     * @dev Internal function to get the metadata edits
     * @param edits The array of metadata edits
     * @param params The parameters for the edits
     * @return finalIndex_ The index of the last edit
     * @return hasMore_ True if there are more edits, false otherwise
     *********************************************************************************************/
    function _getEdits(
        MetadataEditInfo[] memory edits,
        EditParams memory params
    ) private view returns (uint256 finalIndex_, bool hasMore_) {
        uint256 found;
        uint256 editCounter;

        for (uint256 i = 0; i < tokensMetadataWithEdits[params.chainID].length && found < params.size; i++) {
            address tokenAddr = tokensMetadataWithEdits[params.chainID][i];
            uint256 tokenEditCount = editCount[params.chainID][tokenAddr];

            for (uint256 j = 1; j <= tokenEditCount && found < params.size; j++) {
                if (editCounter >= params.initialIndex) {
                    MetadataEditProposal storage proposal = editsOnTokens[params.chainID][tokenAddr][j];
                    if (proposal.submitter != address(0)) {
                        edits[found] = MetadataEditInfo({
                            token: tokenAddr,
                            submitter: proposal.submitter,
                            updates: proposal.updates,
                            chainID: proposal.chainID,
                            editIndex: j,
                            timestamp: proposal.timestamp
                        });
                        found++;
                        finalIndex_ = editCounter;
                    }
                }
                editCounter++;
            }
        }

        hasMore_ = (params.totalEdits - params.initialIndex) > params.size;
    }

    /**********************************************************************************************
     * @dev Internal function to check if a field is valid
     * @param field The name of the metadata field
     * @return bool True if the field is valid, false otherwise
     *********************************************************************************************/
    function _isValidField(string memory field) internal view returns (bool) {
        uint256 index = fieldIndices[field];
        if (index == 0) return false;

        return metadataFields[index - 1].isActive;
    }

    /**********************************************************************************************
     *  _____     _              _             _ _
     * |_   _|__ | | _____ _ __ | |_ _ __ ___ | | | ___ _ __
     *   | |/ _ \| |/ / _ \ '_ \| __| '__/ _ \| | |/ _ \ '__|
     *   | | (_) |   <  __/ | | | |_| | | (_) | | |  __/ |
     *   |_|\___/|_|\_\___|_| |_|\__|_|  \___/|_|_|\___|_|
     *
     * @dev All the functions below are to manage the tokens in the registry with tokentroller.
     * All the verifications are handled by the Tokentroller contract, which can be upgraded at
     * any time by the owner of the contract.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Function to update the tokentroller address
     * @param _newTokentroller The address of the new tokentroller
     * @notice This function can only be called by the tokentroller
     * @notice The new tokentroller address must be valid
     * @notice Emits a TokentrollerUpdated event upon successful update
     *********************************************************************************************/
    function updateTokentroller(address _newTokentroller) public {
        require(msg.sender == tokentroller, "Only the tokentroller can call this function");
        tokentroller = _newTokentroller;
        emit TokentrollerUpdated(_newTokentroller);
    }
}
