// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenRegistry.sol";
import "./interfaces/ITokentroller.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenEdits.sol";
import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableMap.sol";

contract TokenEdits is ITokenEdits {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // Storage for edits - maps token address => edit index => logoURI
    mapping(address => mapping(uint256 => string)) public edits;
    EnumerableMap.AddressToUintMap private tokensWithEdits; // token address => edit count

    // Governance
    address public tokentroller;
    address public tokenRegistry;

    constructor(address _tokentroller, address _tokenRegistry) {
        tokentroller = _tokentroller;
        tokenRegistry = _tokenRegistry;
    }

    function proposeEdit(address contractAddress, string calldata logoURI) external {
        require(
            ITokentroller(tokentroller).canProposeTokenEdit(msg.sender, contractAddress),
            "Not authorized to propose edit"
        );

        (, uint256 currentEditCount) = tokensWithEdits.tryGet(contractAddress);
        currentEditCount++;

        edits[contractAddress][currentEditCount] = logoURI;
        tokensWithEdits.set(contractAddress, currentEditCount);

        emit EditProposed(contractAddress, msg.sender, logoURI);
    }

    function acceptEdit(address contractAddress, uint256 editIndex) external {
        require(
            ITokentroller(tokentroller).canAcceptTokenEdit(msg.sender, contractAddress, editIndex),
            "Not authorized to accept edit"
        );

        (bool exists, uint256 currentEditCount) = tokensWithEdits.tryGet(contractAddress);
        require(exists, "No edits exist");
        require(editIndex <= currentEditCount, "Invalid edit index");

        string memory logoURI = edits[contractAddress][editIndex];
        require(bytes(logoURI).length > 0, "Edit does not exist");

        // Update the token in the registry
        TokenRegistry(tokenRegistry).updateToken(contractAddress, logoURI);

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

        string memory logoURI = edits[contractAddress][editIndex];
        require(bytes(logoURI).length > 0, "Edit does not exist");

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

    function getTokenEdits(address token) external view returns (string[] memory) {
        uint256 count = getEditCount(token);
        string[] memory result = new string[](count);
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
    ) external view returns (string[] memory logoURIs, uint256 total) {
        uint256 totalTokens = tokensWithEdits.length();
        if (initialIndex >= totalTokens) {
            return (new string[](0), totalTokens);
        }

        uint256 endIndex = initialIndex + size;
        if (endIndex > totalTokens) {
            endIndex = totalTokens;
        }

        string[] memory result = new string[](endIndex - initialIndex);
        for (uint256 i = initialIndex; i < endIndex; i++) {
            (address token, uint256 editCount) = tokensWithEdits.at(i);
            result[i - initialIndex] = edits[token][editCount];
        }

        return (result, totalTokens);
    }

    function updateTokentroller(address newTokentroller) external {
        require(msg.sender == tokentroller, "Not authorized");
        tokentroller = newTokentroller;
    }
}
