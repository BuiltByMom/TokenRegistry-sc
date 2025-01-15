// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokenMetadataEdits.sol";
import "./interfaces/ITokentroller.sol";
import "./interfaces/ITokenMetadataRegistry.sol";
import "./interfaces/ISharedTypes.sol";

contract TokenMetadataEdits is ITokenMetadataEdits {
    // Storage
    mapping(uint256 => mapping(address => mapping(uint256 => MetadataEditProposal))) public editsOnTokens;
    mapping(uint256 => mapping(address => uint256)) public editCount;
    mapping(uint256 => address[]) public tokensMetadataWithEdits;

    // Governance
    address public tokentroller;
    address public metadataRegistry;

    constructor(address _tokentroller, address _metadataRegistry) {
        tokentroller = _tokentroller;
        metadataRegistry = _metadataRegistry;
    }

    function proposeMetadataEdit(address token, uint256 chainID, MetadataInput[] calldata updates) external {
        require(
            ITokentroller(tokentroller).canProposeMetadataEdit(msg.sender, token, chainID, updates),
            "Not authorized"
        );
        require(updates.length > 0, "No updates provided");

        // Validate all fields
        for (uint256 i = 0; i < updates.length; i++) {
            require(ITokenMetadataRegistry(metadataRegistry).isValidField(updates[i].field), "Invalid field");
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

    function acceptMetadataEdit(address token, uint256 chainID, uint256 editIndex) external {
        require(
            ITokentroller(tokentroller).canAcceptMetadataEdit(msg.sender, token, chainID, editIndex),
            "Not authorized"
        );
        require(editIndex <= editCount[chainID][token], "Invalid edit index");
        require(editCount[chainID][token] > 0, "No edit exists");

        MetadataEditProposal storage edit = editsOnTokens[chainID][token][editIndex];

        ITokenMetadataRegistry(metadataRegistry).updateMetadata(token, chainID, edit.updates);

        // Clear all edits and remove from tracking
        for (uint256 i = 1; i <= editCount[chainID][token]; i++) {
            delete editsOnTokens[chainID][token][i];
        }
        editCount[chainID][token] = 0;

        _removeTokenFromEdits(chainID, token);

        emit MetadataEditAccepted(token, editIndex, chainID);
    }

    function rejectMetadataEdit(address token, uint256 chainID, uint256 editIndex, string calldata reason) external {
        require(
            ITokentroller(tokentroller).canRejectMetadataEdit(msg.sender, token, chainID, editIndex),
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

    function listAllEdits(
        uint256 chainID,
        uint256 initialIndex,
        uint256 size
    ) external view returns (MetadataEditInfo[] memory edits, uint256 finalIndex, bool hasMore) {
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
        edits = new MetadataEditInfo[](arraySize);

        uint256 found;
        uint256 editCounter;

        for (uint256 i = 0; i < tokensMetadataWithEdits[chainID].length && found < arraySize; i++) {
            address tokenAddr = tokensMetadataWithEdits[chainID][i];
            uint256 tokenEditCount = editCount[chainID][tokenAddr];

            for (uint256 j = 1; j <= tokenEditCount && found < arraySize; j++) {
                if (editCounter >= initialIndex) {
                    MetadataEditProposal storage proposal = editsOnTokens[chainID][tokenAddr][j];
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
                        finalIndex = editCounter;
                    }
                }
                editCounter++;
            }
        }

        hasMore = (totalEdits - initialIndex) > size;
    }

    function tokensMetadataWithEditsLength(uint256 chainID) external view returns (uint256) {
        return tokensMetadataWithEdits[chainID].length;
    }

    function getTokensMetadataWithEdits(uint256 chainID, uint256 index) external view returns (address) {
        return tokensMetadataWithEdits[chainID][index];
    }

    function getEditCount(uint256 chainID, address token) external view returns (uint256) {
        return editCount[chainID][token];
    }

    function getEditProposal(
        uint256 chainID,
        address token,
        uint256 editIndex
    ) external view returns (MetadataEditProposal memory) {
        return editsOnTokens[chainID][token][editIndex];
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

    function updateTokentroller(address newTokentroller) external {
        require(msg.sender == tokentroller, "Only tokentroller can update");
        tokentroller = newTokentroller;
        emit TokentrollerUpdated(newTokentroller);
    }
}
