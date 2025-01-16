// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenRegistry.sol";
import "./interfaces/ITokentroller.sol";
import "./interfaces/ITokenMetadataEdits.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenEdits.sol";

contract TokenEdits is ITokenEdits {
    // Storage
    mapping(uint256 => mapping(address => mapping(uint256 => TokenEdit))) public editsOnTokens;
    mapping(uint256 => mapping(address => uint256)) public editCount;
    mapping(uint256 => address[]) public tokensWithEdits;

    // Governance
    address public tokenRegistry;
    address public tokentroller;
    address public metadataEdits;

    constructor(address _tokenRegistry, address _metadataEdits) {
        tokenRegistry = _tokenRegistry;
        tokentroller = TokenRegistry(tokenRegistry).tokentroller();
        metadataEdits = _metadataEdits;
    }

    function proposeEdit(
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals,
        uint256 chainID
    ) public {
        require(
            ITokentroller(tokentroller).canProposeTokenEdit(msg.sender, contractAddress, chainID),
            "Not authorized to propose edit"
        );

        uint256 newIndex = ++editCount[chainID][contractAddress];

        // Add to tokensWithEdits if this is the first edit
        if (newIndex == 1) {
            tokensWithEdits[chainID].push(contractAddress);
        }

        editsOnTokens[chainID][contractAddress][newIndex] = TokenEdit({
            submitter: msg.sender,
            chainID: chainID,
            name: name,
            symbol: symbol,
            logoURI: logoURI,
            decimals: decimals,
            timestamp: block.timestamp
        });

        emit EditProposed(contractAddress, msg.sender, name, symbol, logoURI, decimals, chainID);
    }

    function acceptEdit(address contractAddress, uint256 editIndex, uint256 chainID) external {
        require(
            ITokentroller(tokentroller).canAcceptTokenEdit(msg.sender, contractAddress, chainID, editIndex),
            "Not authorized to accept edit"
        );
        require(editIndex <= editCount[chainID][contractAddress], "Invalid edit index");
        require(editCount[chainID][contractAddress] > 0, "No edits exist");

        TokenEdit storage edit = editsOnTokens[chainID][contractAddress][editIndex];
        require(edit.submitter != address(0), "Edit does not exist");

        // Update the token in the registry
        TokenRegistry(tokenRegistry).updateToken(
            chainID,
            contractAddress,
            edit.name,
            edit.symbol,
            edit.logoURI,
            edit.decimals
        );

        // Clear all edits and remove from tracking
        for (uint256 i = 1; i <= editCount[chainID][contractAddress]; i++) {
            delete editsOnTokens[chainID][contractAddress][i];
        }
        editCount[chainID][contractAddress] = 0;

        _removeTokenFromEdits(chainID, contractAddress);

        emit EditAccepted(contractAddress, editIndex, chainID);
    }

    function rejectEdit(address contractAddress, uint256 editIndex, uint256 chainID, string calldata reason) external {
        require(
            ITokentroller(tokentroller).canRejectTokenEdit(msg.sender, contractAddress, chainID, editIndex),
            "Not authorized to reject edit"
        );
        require(editIndex <= editCount[chainID][contractAddress], "Invalid edit index");
        require(editCount[chainID][contractAddress] > 0, "No edits exist");

        TokenEdit storage edit = editsOnTokens[chainID][contractAddress][editIndex];
        require(edit.submitter != address(0), "Edit does not exist");

        // Clear the rejected edit
        delete editsOnTokens[chainID][contractAddress][editIndex];
        editCount[chainID][contractAddress]--;

        // If no more edits, remove from tracking
        if (editCount[chainID][contractAddress] == 0) {
            _removeTokenFromEdits(chainID, contractAddress);
        }

        emit EditRejected(contractAddress, editIndex, chainID, reason);
    }

    function listEdits(
        uint256 chainID,
        uint256 initialIndex,
        uint256 size
    ) public view returns (TokenEdit[] memory edits, uint256 finalIndex, bool hasMore) {
        require(size > 0, "Size must be greater than zero");

        // Count total edits
        uint256 totalEdits = 0;
        for (uint256 i = 0; i < tokensWithEdits[chainID].length; i++) {
            totalEdits += editCount[chainID][tokensWithEdits[chainID][i]];
        }

        if (totalEdits == 0 || initialIndex >= totalEdits) {
            return (new TokenEdit[](0), 0, false);
        }

        uint256 arraySize = size > (totalEdits - initialIndex) ? (totalEdits - initialIndex) : size;
        edits = new TokenEdit[](arraySize);

        EditParams memory params = EditParams({
            chainID: chainID,
            initialIndex: initialIndex,
            size: arraySize,
            totalEdits: totalEdits
        });

        (finalIndex, hasMore) = _getEdits(edits, params);
    }

    function getTokensWithEditsCount(uint256 chainID) external view returns (uint256) {
        return tokensWithEdits[chainID].length;
    }

    function getTokenWithEdits(uint256 chainID, uint256 index) external view returns (address) {
        return tokensWithEdits[chainID][index];
    }

    function getEditCount(uint256 chainID, address token) external view returns (uint256) {
        return editCount[chainID][token];
    }

    function _getEdits(
        TokenEdit[] memory edits,
        EditParams memory params
    ) private view returns (uint256 finalIndex, bool hasMore) {
        uint256 found;
        uint256 editCounter;

        for (uint256 i = 0; i < tokensWithEdits[params.chainID].length && found < params.size; i++) {
            address tokenAddr = tokensWithEdits[params.chainID][i];
            uint256 tokenEditCount = editCount[params.chainID][tokenAddr];

            for (uint256 j = 1; j <= tokenEditCount && found < params.size; j++) {
                if (editCounter >= params.initialIndex) {
                    TokenEdit memory edit = editsOnTokens[params.chainID][tokenAddr][j];
                    if (edit.submitter != address(0)) {
                        edits[found] = TokenEdit({
                            submitter: edit.submitter,
                            chainID: edit.chainID,
                            name: edit.name,
                            symbol: edit.symbol,
                            decimals: edit.decimals,
                            logoURI: edit.logoURI,
                            timestamp: edit.timestamp
                        });
                        found++;
                        finalIndex = editCounter;
                    }
                }
                editCounter++;
            }
        }

        hasMore = (params.totalEdits - params.initialIndex) > params.size;
    }

    // Internal Functions
    function _removeTokenFromEdits(uint256 chainID, address token) internal {
        address[] storage edits = tokensWithEdits[chainID];
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
