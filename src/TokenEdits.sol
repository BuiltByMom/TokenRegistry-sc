// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokenRegistry.sol";
import "./interfaces/ITokentroller.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenEdits.sol";
import "./interfaces/ITokenMetadata.sol";
import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableMap.sol";
import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

contract TokenEdits is ITokenEdits {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.UintSet;

    // Sequential ID for edits
    uint256 private nextEditId;

    // Token => edit ID => metadata
    mapping(address => mapping(uint256 => MetadataInput[])) public edits;

    // Token => set of active edit IDs
    mapping(address => EnumerableSet.UintSet) private tokenActiveEdits;

    // Token => number of active edits (for EnumerableMap compatibility)
    EnumerableMap.AddressToUintMap private tokensWithEdits;

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

        uint256 editId = ++nextEditId;
        MetadataInput[] storage editArray = edits[contractAddress][editId];
        for (uint256 i = 0; i < metadata.length; i++) {
            editArray.push(metadata[i]);
        }

        EnumerableSet.add(tokenActiveEdits[contractAddress], editId);
        (, uint256 currentCount) = tokensWithEdits.tryGet(contractAddress);
        tokensWithEdits.set(contractAddress, currentCount + 1);

        emit EditProposed(contractAddress, msg.sender, metadata);
    }

    function acceptEdit(address contractAddress, uint256 editId) external {
        require(
            ITokentroller(tokentroller).canAcceptTokenEdit(msg.sender, contractAddress, editId),
            "Not authorized to accept edit"
        );

        require(EnumerableSet.contains(tokenActiveEdits[contractAddress], editId), "Edit not found");

        MetadataInput[] memory metadata = edits[contractAddress][editId];
        require(metadata.length > 0, "Edit does not exist");

        ITokenMetadata(tokenMetadata).updateMetadata(contractAddress, metadata);

        // Clear all edits for this token
        uint256[] memory activeIds = EnumerableSet.values(tokenActiveEdits[contractAddress]);
        for (uint256 i = 0; i < activeIds.length; i++) {
            uint256 id = activeIds[i];
            delete edits[contractAddress][id];
            EnumerableSet.remove(tokenActiveEdits[contractAddress], id);
        }
        tokensWithEdits.remove(contractAddress);

        emit EditAccepted(contractAddress, editId);
    }

    function rejectEdit(address contractAddress, uint256 editId, string calldata reason) external {
        require(
            ITokentroller(tokentroller).canRejectTokenEdit(msg.sender, contractAddress, editId),
            "Not authorized to reject edit"
        );

        require(EnumerableSet.contains(tokenActiveEdits[contractAddress], editId), "Edit not found");

        delete edits[contractAddress][editId];
        EnumerableSet.remove(tokenActiveEdits[contractAddress], editId);

        (, uint256 currentCount) = tokensWithEdits.tryGet(contractAddress);
        if (currentCount == 1) {
            tokensWithEdits.remove(contractAddress);
        } else {
            tokensWithEdits.set(contractAddress, currentCount - 1);
        }

        emit EditRejected(contractAddress, editId, reason);
    }

    function getTokensWithEditsCount() external view returns (uint256) {
        return tokensWithEdits.length();
    }

    function getTokenEdits(address token) external view returns (MetadataInput[][] memory) {
        uint256[] memory activeIds = EnumerableSet.values(tokenActiveEdits[token]);
        MetadataInput[][] memory result = new MetadataInput[][](activeIds.length);

        for (uint256 i = 0; i < activeIds.length; i++) {
            result[i] = edits[token][activeIds[i]];
        }
        return result;
    }

    function getEditCount(address token) public view returns (uint256) {
        return EnumerableSet.length(tokenActiveEdits[token]);
    }

    function listEdits(
        uint256 initialIndex,
        uint256 size
    ) external view returns (TokenEdit[] memory tokenEdits, uint256 total) {
        uint256 totalTokens = tokensWithEdits.length();
        if (initialIndex >= totalTokens) {
            return (new TokenEdit[](0), totalTokens);
        }

        uint256 endIndex = initialIndex + size;
        if (endIndex > totalTokens) {
            endIndex = totalTokens;
        }

        TokenEdit[] memory result = new TokenEdit[](endIndex - initialIndex);
        for (uint256 i = initialIndex; i < endIndex; i++) {
            (address token, ) = tokensWithEdits.at(i);

            uint256[] memory activeIds = EnumerableSet.values(tokenActiveEdits[token]);
            MetadataInput[][] memory tokenUpdates = new MetadataInput[][](activeIds.length);

            for (uint256 j = 0; j < activeIds.length; j++) {
                tokenUpdates[j] = edits[token][activeIds[j]];
            }

            result[i - initialIndex] = TokenEdit({ token: token, updates: tokenUpdates });
        }

        return (result, totalTokens);
    }

    function updateTokentroller(address newTokentroller) external {
        require(msg.sender == tokentroller, "Not authorized");
        tokentroller = newTokentroller;
    }
}
