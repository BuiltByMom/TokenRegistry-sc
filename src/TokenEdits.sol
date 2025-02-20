// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ITokenRegistry.sol";
import "./interfaces/ITokentroller.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenEdits.sol";
import "./interfaces/ITokenMetadata.sol";
import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableMap.sol";
import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/**********************************************************************************************
 * @title TokenEdits
 * @dev A contract that manages the proposal and approval of token metadata edits.
 * This contract allows community members to propose changes to token metadata,
 * which can then be approved or rejected by governance.
 *********************************************************************************************/
contract TokenEdits is ITokenEdits, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Sequential ID for edits
    uint256 private nextEditId;

    // Token => edit ID => metadata
    mapping(address => mapping(uint256 => MetadataInput[])) public edits;

    // Token => set of active edit IDs
    mapping(address => EnumerableSet.UintSet) private tokenActiveEdits;

    // Set of tokens that have active edits
    EnumerableSet.AddressSet private tokensWithEdits;

    // Governance
    address public tokentroller;
    address public immutable tokenMetadata;

    /**********************************************************************************************
     * @dev Constructor for the TokenEdits contract
     * @param _tokentroller The address of the tokentroller contract
     * @param _tokenMetadata The address of the token metadata contract
     * @notice Initializes the contract with the tokentroller and metadata contract addresses
     *********************************************************************************************/
    constructor(address _tokentroller, address _tokenMetadata) {
        require(_tokentroller != address(0), "TokenEdits: tokentroller cannot be zero address");
        require(_tokenMetadata != address(0), "TokenEdits: tokenMetadata cannot be zero address");
        tokentroller = _tokentroller;
        tokenMetadata = _tokenMetadata;
    }

    /**********************************************************************************************
     *  __  __       _        _
     * |  \/  |_   _| |_ __ _| |_ ___  _ __ ___
     * | |\/| | | | | __/ _` | __/ _ \| '__/ __|
     * | |  | | |_| | || (_| | || (_) | |  \__ \
     * |_|  |_|\__,_|\__\__,_|\__\___/|_|  |___/
     *
     * @dev These functions are designed to alter the state of the edits.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Proposes an edit to a token's metadata
     * @param contractAddress The address of the token contract
     * @param metadata Array of metadata fields and values to update
     * @notice This function can only be called by authorized addresses
     * @notice The metadata array cannot be empty and must contain valid fields and values
     * @notice Emits an EditProposed event on success
     *********************************************************************************************/
    function proposeEdit(address contractAddress, MetadataInput[] calldata metadata) external returns (uint256) {
        require(
            ITokentroller(tokentroller).canProposeTokenEdit(msg.sender, contractAddress),
            "Not authorized to propose edit"
        );

        require(metadata.length > 0, "Empty metadata array");

        uint256 editId = ++nextEditId;
        MetadataInput[] storage editArray = edits[contractAddress][editId];
        for (uint256 i = 0; i < metadata.length; i++) {
            require(bytes(metadata[i].field).length > 0, "Empty field name");
            require(bytes(metadata[i].value).length > 0, "Empty value");
            editArray.push(metadata[i]);
        }

        // Add edit to active edits
        bool added = EnumerableSet.add(tokenActiveEdits[contractAddress], editId);
        require(added, "Failed to add edit to active edits");

        // Add token to tracking set if not already tracked
        if (!tokensWithEdits.contains(contractAddress)) {
            bool success = tokensWithEdits.add(contractAddress);
            require(success, "Failed to add token to tracking");
        }

        emit EditProposed(contractAddress, editId, msg.sender, metadata);

        return editId;
    }

    /**********************************************************************************************
     * @dev Accepts a proposed edit for a token
     * @param contractAddress The address of the token contract
     * @param editId The ID of the edit to accept
     * @notice This function can only be called by authorized addresses
     * @notice The edit must exist and be active
     * @notice Accepting an edit will clear all other pending edits for the token
     * @notice Emits an EditAccepted event on success
     *********************************************************************************************/
    function acceptEdit(address contractAddress, uint256 editId) external nonReentrant {
        require(
            ITokentroller(tokentroller).canAcceptTokenEdit(msg.sender, contractAddress, editId),
            "Not authorized to accept edit"
        );
        require(EnumerableSet.contains(tokenActiveEdits[contractAddress], editId), "Edit not found");

        MetadataInput[] memory metadata = edits[contractAddress][editId];
        require(metadata.length > 0, "Edit does not exist");

        // Clear all edits for this token
        uint256[] memory activeIds = EnumerableSet.values(tokenActiveEdits[contractAddress]);
        for (uint256 i = 0; i < activeIds.length; i++) {
            uint256 id = activeIds[i];
            delete edits[contractAddress][id];
            bool removed = EnumerableSet.remove(tokenActiveEdits[contractAddress], id);
            require(removed, "Failed to remove edit");
            emit EditRejected(contractAddress, id, "Edit cleared due to another edit being accepted");
        }

        bool exists = tokensWithEdits.contains(contractAddress);
        require(exists, "Token not found in edit tracking");
        bool success = tokensWithEdits.remove(contractAddress);
        require(success, "Failed to remove token from edit tracking");

        MetadataInput[] memory metadataToUpdate = metadata;

        ITokenMetadata(tokenMetadata).updateMetadata(contractAddress, metadataToUpdate);

        emit EditAccepted(contractAddress, editId);
    }

    /**********************************************************************************************
     * @dev Rejects a proposed edit for a token
     * @param contractAddress The address of the token contract
     * @param editId The ID of the edit to reject
     * @param reason The reason for rejecting the edit
     * @notice This function can only be called by authorized addresses
     * @notice The edit must exist and be active
     * @notice Emits an EditRejected event on success
     *********************************************************************************************/
    function rejectEdit(address contractAddress, uint256 editId, string calldata reason) external {
        require(
            ITokentroller(tokentroller).canRejectTokenEdit(msg.sender, contractAddress, editId),
            "Not authorized to reject edit"
        );

        require(EnumerableSet.contains(tokenActiveEdits[contractAddress], editId), "Edit not found");

        delete edits[contractAddress][editId];
        bool removed = EnumerableSet.remove(tokenActiveEdits[contractAddress], editId);
        require(removed, "Failed to remove edit");

        // If this was the last edit, remove token from tracking
        if (getEditCount(contractAddress) == 0) {
            bool success = tokensWithEdits.remove(contractAddress);
            require(success, "Failed to remove token from tracking");
        }

        emit EditRejected(contractAddress, editId, reason);
    }

    /**********************************************************************************************
     *     _
     *    / \   ___ ___ ___  ___ ___  ___  _ __ ___
     *   / _ \ / __/ __/ _ \/ __/ __|/ _ \| '__/ __|
     *  / ___ \ (_| (_|  __/\__ \__ \ (_) | |  \__ \
     * /_/   \_\___\___\___||___/___/\___/|_|  |___/
     *
     * @dev These functions are for the public to get information about the edits.
     * They do not require any special permissions or access control and are read-only.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Gets the total number of tokens with pending edits
     * @return uint256 The number of tokens that have pending edits
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function getTokensWithEditsCount() external view returns (uint256) {
        return tokensWithEdits.length();
    }

    /**********************************************************************************************
     * @dev Gets all pending edits for a specific token
     * @param token The address of the token contract
     * @return editIds Array of edit IDs
     * @return updates Array of metadata updates corresponding to each edit ID
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function getTokenEdits(
        address token
    ) external view returns (uint256[] memory editIds, MetadataInput[][] memory updates) {
        uint256[] memory activeIds = EnumerableSet.values(tokenActiveEdits[token]);
        editIds = activeIds;
        updates = new MetadataInput[][](activeIds.length);

        for (uint256 i = 0; i < activeIds.length; i++) {
            updates[i] = edits[token][activeIds[i]];
        }
        return (editIds, updates);
    }

    /**********************************************************************************************
     * @dev Gets the number of pending edits for a specific token
     * @param token The address of the token contract
     * @return uint256 The number of pending edits for the token
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function getEditCount(address token) public view returns (uint256) {
        return EnumerableSet.length(tokenActiveEdits[token]);
    }

    /**********************************************************************************************
     * @dev Lists pending edits with pagination
     * @param initialIndex The starting index for pagination
     * @param size The number of items to return
     * @return tokenEdits Array of TokenEdit structs containing edit information
     * @return total Total number of tokens with edits
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function listEdits(
        uint256 initialIndex,
        uint256 size
    ) external view returns (TokenEdit[] memory tokenEdits, uint256 total) {
        total = tokensWithEdits.length();
        if (initialIndex >= total) {
            return (new TokenEdit[](0), total);
        }

        uint256 endIndex = initialIndex + size;
        if (endIndex > total) {
            endIndex = total;
        }

        TokenEdit[] memory result = new TokenEdit[](endIndex - initialIndex);
        for (uint256 i = initialIndex; i < endIndex; i++) {
            address token = tokensWithEdits.at(i);

            uint256[] memory activeIds = EnumerableSet.values(tokenActiveEdits[token]);
            MetadataInput[][] memory tokenUpdates = new MetadataInput[][](activeIds.length);

            for (uint256 j = 0; j < activeIds.length; j++) {
                tokenUpdates[j] = edits[token][activeIds[j]];
            }

            result[i - initialIndex] = TokenEdit({ token: token, editIds: activeIds, updates: tokenUpdates });
        }

        return (result, total);
    }

    /**********************************************************************************************
     *  _____     _              _             _ _
     * |_   _|__ | | _____ _ __ | |_ _ __ ___ | | | ___ _ __
     *   | |/ _ \| |/ / _ \ '_ \| __| '__/ _ \| | |/ _ \ '__|
     *   | | (_) |   <  __/ | | | |_| | | (_) | | |  __/ |
     *   |_|\___/|_|\_\___|_| |_|\__|_|  \___/|_|_|\___|_|
     *
     * @dev All the functions below are to manage the edits with tokentroller.
     * All the verifications are handled by the Tokentroller contract, which can be upgraded at
     * any time by the owner of the contract.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Updates the tokentroller address
     * @param newTokentroller The address of the new tokentroller
     * @notice This function can only be called by the current tokentroller
     * @notice Emits a TokentrollerUpdated event on success
     *********************************************************************************************/
    function updateTokentroller(address newTokentroller) external {
        require(msg.sender == tokentroller, "Not authorized");
        require(newTokentroller != address(0), "TokenEdits: tokentroller cannot be zero address");
        tokentroller = newTokentroller;
        emit TokentrollerUpdated(newTokentroller);
    }
}
