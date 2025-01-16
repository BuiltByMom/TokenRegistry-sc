// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenRegistry.sol";
import "./interfaces/ITokentroller.sol";
import "./interfaces/ITokenMetadataEdits.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenEdits.sol";

contract TokenEdits is ITokenEdits {
    // Storage
    mapping(address => mapping(uint256 => TokenEdit)) public editsOnTokens;
    mapping(address => uint256) public editCount;
    address[] public tokensWithEdits;

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
        uint8 decimals
    ) external {
        require(
            ITokentroller(tokentroller).canProposeTokenEdit(msg.sender, contractAddress),
            "Not authorized to propose edit"
        );

        editCount[contractAddress]++;
        uint256 currentEditIndex = editCount[contractAddress];

        editsOnTokens[contractAddress][currentEditIndex] = TokenEdit({
            submitter: msg.sender,
            name: name,
            symbol: symbol,
            logoURI: logoURI,
            decimals: decimals,
            timestamp: block.timestamp
        });

        if (!_isTokenInEdits(contractAddress)) {
            tokensWithEdits.push(contractAddress);
        }

        emit EditProposed(contractAddress, msg.sender, name, symbol, logoURI, decimals);
    }

    function acceptEdit(address contractAddress, uint256 editIndex) external {
        require(
            ITokentroller(tokentroller).canAcceptTokenEdit(msg.sender, contractAddress, editIndex),
            "Not authorized to accept edit"
        );
        require(editIndex <= editCount[contractAddress], "Invalid edit index");
        require(editCount[contractAddress] > 0, "No edits exist");

        TokenEdit storage edit = editsOnTokens[contractAddress][editIndex];
        require(edit.submitter != address(0), "Edit does not exist");

        // Update the token in the registry
        TokenRegistry(tokenRegistry).updateToken(contractAddress, edit.name, edit.symbol, edit.logoURI, edit.decimals);

        // Clear all edits and remove from tracking
        for (uint256 i = 1; i <= editCount[contractAddress]; i++) {
            delete editsOnTokens[contractAddress][i];
        }
        editCount[contractAddress] = 0;

        _removeTokenFromEdits(contractAddress);

        emit EditAccepted(contractAddress, editIndex);
    }

    function rejectEdit(address contractAddress, uint256 editIndex, string calldata reason) external {
        require(
            ITokentroller(tokentroller).canRejectTokenEdit(msg.sender, contractAddress, editIndex),
            "Not authorized to reject edit"
        );
        require(editIndex <= editCount[contractAddress], "Invalid edit index");
        require(editCount[contractAddress] > 0, "No edits exist");

        TokenEdit storage edit = editsOnTokens[contractAddress][editIndex];
        require(edit.submitter != address(0), "Edit does not exist");

        // Clear the rejected edit
        delete editsOnTokens[contractAddress][editIndex];
        editCount[contractAddress]--;

        // If no more edits, remove from tracking
        if (editCount[contractAddress] == 0) {
            _removeTokenFromEdits(contractAddress);
        }

        emit EditRejected(contractAddress, editIndex, reason);
    }

    function listEdits(
        uint256 initialIndex,
        uint256 size
    ) public view returns (TokenEdit[] memory edits, uint256 finalIndex, bool hasMore) {
        require(size > 0, "Size must be greater than zero");

        // Count total edits
        uint256 totalEdits = 0;
        for (uint256 i = 0; i < tokensWithEdits.length; i++) {
            totalEdits += editCount[tokensWithEdits[i]];
        }

        if (totalEdits == 0 || initialIndex >= totalEdits) {
            return (new TokenEdit[](0), 0, false);
        }

        uint256 arraySize = size > (totalEdits - initialIndex) ? (totalEdits - initialIndex) : size;
        edits = new TokenEdit[](arraySize);

        EditParams memory params = EditParams({ initialIndex: initialIndex, size: arraySize, totalEdits: totalEdits });

        (finalIndex, hasMore) = _getEdits(edits, params);
    }

    function getTokensWithEditsCount() external view returns (uint256) {
        return tokensWithEdits.length;
    }

    function getTokenWithEdits(uint256 index) external view returns (address) {
        return tokensWithEdits[index];
    }

    function getEditCount(address token) external view returns (uint256) {
        return editCount[token];
    }

    function _getEdits(
        TokenEdit[] memory edits,
        EditParams memory params
    ) private view returns (uint256 finalIndex, bool hasMore) {
        uint256 found;
        uint256 editCounter;

        for (uint256 i = 0; i < tokensWithEdits.length && found < params.size; i++) {
            address tokenAddr = tokensWithEdits[i];
            uint256 tokenEditCount = editCount[tokenAddr];

            for (uint256 j = 1; j <= tokenEditCount && found < params.size; j++) {
                if (editCounter >= params.initialIndex) {
                    TokenEdit memory edit = editsOnTokens[tokenAddr][j];
                    if (edit.submitter != address(0)) {
                        edits[found] = TokenEdit({
                            submitter: edit.submitter,
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

    function _isTokenInEdits(address token) internal view returns (bool) {
        for (uint256 i = 0; i < tokensWithEdits.length; i++) {
            if (tokensWithEdits[i] == token) {
                return true;
            }
        }
        return false;
    }

    // Internal Functions
    function _removeTokenFromEdits(address token) internal {
        for (uint256 i = 0; i < tokensWithEdits.length; i++) {
            if (tokensWithEdits[i] == token) {
                tokensWithEdits[i] = tokensWithEdits[tokensWithEdits.length - 1];
                tokensWithEdits.pop();
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
