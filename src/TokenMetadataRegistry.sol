// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokentroller.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenMetadataRegistry.sol";

contract TokenMetadataRegistry is ITokenMetadataRegistry {
    address public tokentroller;

    MetadataField[] public metadataFields;
    mapping(string => uint256) public fieldIndices;
    mapping(uint256 => mapping(address => mapping(string => string))) public tokenMetadata;

    mapping(uint256 => mapping(address => mapping(uint256 => MetadataEditProposal))) public editsOnTokens;
    mapping(uint256 => mapping(address => uint256)) public editCount;
    mapping(uint256 => address[]) public tokensMetadataWithEdits;

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

    function setMetadata(address token, uint256 chainID, string calldata field, string calldata value) external {
        require(ITokentroller(tokentroller).canSetMetadata(msg.sender, token, chainID, field), "Not authorized");
        require(_isValidField(field), "Invalid field");
        tokenMetadata[chainID][token][field] = value;
        emit MetadataValueSet(token, chainID, field, value);
    }

    function setMetadataBatch(address token, uint256 chainID, MetadataInput[] calldata metadata) external {
        require(ITokentroller(tokentroller).canSetMetadata(msg.sender, token, chainID, ""), "Not authorized");

        for (uint256 i = 0; i < metadata.length; i++) {
            require(_isValidField(metadata[i].field), "Invalid field");
            tokenMetadata[chainID][token][metadata[i].field] = metadata[i].value;
            emit MetadataValueSet(token, chainID, metadata[i].field, metadata[i].value);
        }
    }

    function getMetadata(address token, uint256 chainID, string calldata field) external view returns (string memory) {
        return tokenMetadata[chainID][token][field];
    }

    function getMetadataFields() external view returns (MetadataField[] memory) {
        return metadataFields;
    }

    function _isValidField(string memory field) internal view returns (bool) {
        uint256 index = fieldIndices[field];
        if (index == 0) return false;

        return metadataFields[index - 1].isActive;
    }

    function updateTokentroller(address _newTokentroller) public {
        require(msg.sender == tokentroller, "Only the tokentroller can call this function");
        tokentroller = _newTokentroller;
        emit TokentrollerUpdated(_newTokentroller);
    }

    // Add this new function
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

    function rejectMetadataEdit(address token, uint256 chainID, uint256 editIndex) external {
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

        emit MetadataEditRejected(token, editIndex, chainID);
    }

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

    function tokensMetadataWithEditsLength(uint256 chainID) public view returns (uint256) {
        return tokensMetadataWithEdits[chainID].length;
    }

    function getTokensMetadataWithEdits(uint256 chainID, uint256 index) public view returns (address) {
        return tokensMetadataWithEdits[chainID][index];
    }

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
}
