// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokentroller.sol";
import "./interfaces/ITokenMetadataRegistry.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenMetadataEdits.sol";

contract TokenMetadataEdits is ITokenMetadataEdits {
    // Mapping of token address => edit index => edit info
    mapping(address => mapping(uint256 => MetadataEditProposal)) public edits;

    // Mapping of token address => number of edits
    mapping(address => uint256) public editCount;

    // Array of tokens that have pending edits
    address[] public tokensWithEdits;

    // Mapping to track if a token is in the tokensWithEdits array
    mapping(address => bool) public hasEdits;

    address public tokentroller;
    address public immutable metadataRegistry;

    constructor(address _tokentroller, address _metadataRegistry) {
        tokentroller = _tokentroller;
        metadataRegistry = _metadataRegistry;
    }

    function proposeMetadataEdit(address token, MetadataInput[] calldata updates) external {
        require(
            ITokentroller(tokentroller).canProposeMetadataEdit(msg.sender, token, updates),
            "Not authorized to propose edit"
        );

        require(updates.length > 0, "No updates provided");

        // Validate all fields
        for (uint256 i = 0; i < updates.length; i++) {
            require(ITokenMetadataRegistry(metadataRegistry).isValidField(updates[i].field), "Invalid field");
        }

        uint256 editIndex = editCount[token] + 1;
        MetadataEditProposal storage newEdit = edits[token][editIndex];
        newEdit.submitter = msg.sender;
        newEdit.timestamp = block.timestamp;

        for (uint256 i = 0; i < updates.length; i++) {
            newEdit.updates.push(updates[i]);
        }

        editCount[token] = editIndex;

        if (!hasEdits[token]) {
            tokensWithEdits.push(token);
            hasEdits[token] = true;
        }

        emit MetadataEditProposed(token, msg.sender, updates);
    }

    function acceptMetadataEdit(address token, uint256 editIndex) external {
        require(
            ITokentroller(tokentroller).canAcceptMetadataEdit(msg.sender, token, editIndex),
            "Not authorized to accept edit"
        );
        require(edits[token][editIndex].submitter != address(0), "Edit does not exist");

        MetadataEditProposal storage edit = edits[token][editIndex];
        ITokenMetadataRegistry(metadataRegistry).updateMetadata(token, edit.updates);

        // Clear all edits for this token
        _clearEdits(token);

        emit MetadataEditAccepted(token, editIndex);
    }

    function rejectMetadataEdit(address token, uint256 editIndex, string calldata reason) external {
        require(
            ITokentroller(tokentroller).canRejectMetadataEdit(msg.sender, token, editIndex),
            "Not authorized to reject edit"
        );
        require(edits[token][editIndex].submitter != address(0), "Edit does not exist");

        // Clear the specific edit
        delete edits[token][editIndex];

        // If no more edits, remove from tracking
        if (editIndex == editCount[token]) {
            editCount[token]--;
            if (editCount[token] == 0) {
                _removeFromTokensWithEdits(token);
            }
        }

        emit MetadataEditRejected(token, editIndex, reason);
    }

    function listAllEdits(
        uint256 initialIndex,
        uint256 size
    ) external view returns (MetadataEditInfo[] memory edits_, uint256 finalIndex, bool hasMore) {
        uint256 totalEdits = 0;
        for (uint256 i = 0; i < tokensWithEdits.length; i++) {
            totalEdits += editCount[tokensWithEdits[i]];
        }

        if (initialIndex >= totalEdits) {
            return (new MetadataEditInfo[](0), initialIndex, false);
        }

        uint256 remaining = totalEdits - initialIndex;
        uint256 count = remaining < size ? remaining : size;
        edits_ = new MetadataEditInfo[](count);

        uint256 found = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < tokensWithEdits.length && found < count; i++) {
            address token = tokensWithEdits[i];
            uint256 tokenEditCount = editCount[token];

            for (uint256 j = 1; j <= tokenEditCount && found < count; j++) {
                if (currentIndex >= initialIndex) {
                    MetadataEditProposal storage edit = edits[token][j];
                    if (edit.submitter != address(0)) {
                        edits_[found] = MetadataEditInfo({
                            token: token,
                            submitter: edit.submitter,
                            updates: edit.updates,
                            editIndex: j,
                            timestamp: edit.timestamp
                        });
                        found++;
                    }
                }
                currentIndex++;
            }
        }

        finalIndex = initialIndex + found;
        hasMore = finalIndex < totalEdits;
    }

    function tokensMetadataWithEditsLength() external view returns (uint256) {
        return tokensWithEdits.length;
    }

    function getTokensMetadataWithEdits(uint256 index) external view returns (address) {
        require(index < tokensWithEdits.length, "Index out of bounds");
        return tokensWithEdits[index];
    }

    function getEditCount(address token) external view returns (uint256) {
        return editCount[token];
    }

    function getEditProposal(address token, uint256 editIndex) external view returns (MetadataEditProposal memory) {
        return edits[token][editIndex];
    }

    function _clearEdits(address token) internal {
        uint256 count = editCount[token];
        for (uint256 i = 1; i <= count; i++) {
            delete edits[token][i];
        }
        editCount[token] = 0;
        _removeFromTokensWithEdits(token);
    }

    function _removeFromTokensWithEdits(address token) internal {
        if (hasEdits[token]) {
            hasEdits[token] = false;
            for (uint256 i = 0; i < tokensWithEdits.length; i++) {
                if (tokensWithEdits[i] == token) {
                    tokensWithEdits[i] = tokensWithEdits[tokensWithEdits.length - 1];
                    tokensWithEdits.pop();
                    break;
                }
            }
        }
    }

    function updateTokentroller(address newTokentroller) external {
        require(msg.sender == tokentroller, "Only tokentroller can update");
        tokentroller = newTokentroller;
        emit TokentrollerUpdated(newTokentroller);
    }
}
