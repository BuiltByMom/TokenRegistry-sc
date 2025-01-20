// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokenRegistry.sol";
import "./interfaces/ITokentroller.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenEdits.sol";
import "./interfaces/ITokenMetadata.sol";
import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableMap.sol";

contract TokenEdits is ITokenEdits {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // Storage for edits - maps token address => edit index => metadata array
    mapping(address => mapping(uint256 => MetadataInput[])) public edits;
    EnumerableMap.AddressToUintMap private tokensWithEdits; // token address => edit count

    // Governance
    address public tokentroller;
    address public tokenMetadata;

    constructor(address _tokentroller, address _tokenMetadata) {
        tokentroller = _tokentroller;
        tokenMetadata = _tokenMetadata;
    }

    function proposeEdit(address contractAddress, MetadataInput[] calldata metadata) external {
        require(
            ITokentroller(tokentroller).canProposeTokenEdit(msg.sender, contractAddress),
            "Not authorized to propose edit"
        );

        (, uint256 currentEditCount) = tokensWithEdits.tryGet(contractAddress);
        currentEditCount++;

        MetadataInput[] storage editArray = edits[contractAddress][currentEditCount];
        for (uint256 i = 0; i < metadata.length; i++) {
            editArray.push(MetadataInput({ field: metadata[i].field, value: metadata[i].value }));
        }

        tokensWithEdits.set(contractAddress, currentEditCount);

        emit EditProposed(contractAddress, msg.sender, metadata);
    }

    function acceptEdit(address contractAddress, uint256 editIndex) external {
        require(
            ITokentroller(tokentroller).canAcceptTokenEdit(msg.sender, contractAddress, editIndex),
            "Not authorized to accept edit"
        );

        (bool exists, uint256 currentEditCount) = tokensWithEdits.tryGet(contractAddress);
        require(exists, "No edits exist");
        require(editIndex <= currentEditCount, "Invalid edit index");

        MetadataInput[] memory metadata = edits[contractAddress][editIndex];
        require(metadata.length > 0, "Edit does not exist");

        ITokenMetadata(tokenMetadata).updateMetadata(contractAddress, metadata);

        // Clear all edits and remove from tracking
        for (uint256 i = 1; i <= currentEditCount; i++) {
            delete edits[contractAddress][i];
        }
        tokensWithEdits.remove(contractAddress);

        emit EditAccepted(contractAddress, editIndex);
    }

    function rejectEdit(address contractAddress, uint256 editIndex, string calldata reason) external {
        require(
            ITokentroller(tokentroller).canRejectTokenEdit(msg.sender, contractAddress, editIndex),
            "Not authorized to reject edit"
        );

        (bool exists, uint256 currentEditCount) = tokensWithEdits.tryGet(contractAddress);
        require(exists, "No edits exist");
        require(editIndex <= currentEditCount, "Invalid edit index");

        MetadataInput[] memory metadata = edits[contractAddress][editIndex];
        require(metadata.length > 0, "Edit does not exist");

        delete edits[contractAddress][editIndex];

        // If this was the last edit, remove token from tracking
        if (editIndex == currentEditCount) {
            if (currentEditCount == 1) {
                tokensWithEdits.remove(contractAddress);
            } else {
                tokensWithEdits.set(contractAddress, currentEditCount - 1);
            }
        }

        emit EditRejected(contractAddress, editIndex, reason);
    }

    function getTokensWithEditsCount() external view returns (uint256) {
        return tokensWithEdits.length();
    }

    function getTokenEdits(address token) external view returns (MetadataInput[][] memory) {
        uint256 count = getEditCount(token);
        MetadataInput[][] memory result = new MetadataInput[][](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = edits[token][i + 1];
        }
        return result;
    }

    function getEditCount(address token) public view returns (uint256) {
        (, uint256 count) = tokensWithEdits.tryGet(token);
        return count;
    }

    function listEdits(
        uint256 initialIndex,
        uint256 size
    ) external view returns (MetadataInput[][] memory metadataEdits, uint256 total) {
        uint256 totalTokens = tokensWithEdits.length();
        if (initialIndex >= totalTokens) {
            return (new MetadataInput[][](0), totalTokens);
        }

        uint256 endIndex = initialIndex + size;
        if (endIndex > totalTokens) {
            endIndex = totalTokens;
        }

        MetadataInput[][] memory result = new MetadataInput[][](endIndex - initialIndex);
        for (uint256 i = initialIndex; i < endIndex; i++) {
            (address token, uint256 editCount) = tokensWithEdits.at(i);
            MetadataInput[] memory tokenEdits = edits[token][editCount];
            result[i - initialIndex] = tokenEdits;
        }

        return (result, totalTokens);
    }

    function updateTokentroller(address newTokentroller) external {
        require(msg.sender == tokentroller, "Not authorized");
        tokentroller = newTokentroller;
    }
}
