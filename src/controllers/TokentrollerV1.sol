// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ITokentroller.sol";
import "../interfaces/ITokenRegistry.sol";
import "../TokenRegistry.sol";
import "../TokenMetadata.sol";
import "../TokenEdits.sol";

contract TokentrollerV1 is ITokentroller {
    address public immutable tokenRegistry;
    address public immutable tokenMetadata;
    address public tokenEdits;
    address public owner;

    mapping(address => bool) public trustedHelpers;

    /**********************************************************************************************
     * @dev Constructor for the Tokentroller contract
     * @param _owner The address of the contract owner
     *********************************************************************************************/
    constructor(address _owner) {
        require(_owner != address(0), "TokentrollerV1: owner cannot be zero address");
        owner = _owner;
        tokenMetadata = address(new TokenMetadata(address(this)));
        tokenRegistry = address(new TokenRegistry(address(this), tokenMetadata));
        tokenEdits = address(new TokenEdits(address(this), tokenMetadata));
    }

    /**********************************************************************************************
     * @dev Updates the token edits contract address
     * @param newTokenEdits The address of the new token edits contract
     * @notice This function can only be called by the owner
     * @notice The new token edits address must not be zero or the current address
     *********************************************************************************************/
    function updateTokenEdits(address newTokenEdits) external virtual {
        require(msg.sender == owner, "Only the owner can call this function");
        require(newTokenEdits != address(0), "New token edits address cannot be zero");
        require(newTokenEdits != tokenEdits, "New token edits address cannot be the same as the current address");
        tokenEdits = newTokenEdits;
    }

    /**********************************************************************************************
     *  __  __       _        _
     * |  \/  |_   _| |_ __ _| |_ ___  _ __ ___
     * | |\/| | | | | __/ _` | __/ _ \| '__/ __|
     * | |  | | |_| | || (_| | || (_) | |  \__ \
     * |_|  |_|\__,_|\__\__,_|\__\___/|_|  |___/
     *
     * @dev These functions are designed to alter the state of the Tokentroller contract, including
     * the tokentroller address in the TokenRegistry contract.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Updates the tokentroller address in the TokenRegistry contract
     * @param newTokentroller The address of the new tokentroller
     * @notice This function can only be called by the owner
     * @notice The new tokentroller address must not be zero or the current contract address
     * @notice Calls the updateTokentroller function in the TokenRegistry contract
     *********************************************************************************************/
    function updateRegistryTokentroller(address newTokentroller) external virtual {
        require(msg.sender == owner, "Only the owner can call this function");
        require(newTokentroller != address(0), "New tokentroller address cannot be zero");
        require(newTokentroller != address(this), "New tokentroller address cannot be the same as the current address");
        TokenRegistry(tokenRegistry).updateTokentroller(newTokentroller);
        TokenEdits(tokenEdits).updateTokentroller(newTokentroller);
    }

    /**********************************************************************************************
     * @dev Updates the tokentroller address in the TokenMetadata contract
     * @param newTokentroller The address of the new tokentroller
     * @notice This function can only be called by the owner
     * @notice The new tokentroller address must not be zero or the current contract address
     * @notice Calls the updateTokentroller function in the TokenMetadata contract
     *********************************************************************************************/
    function updateMetadataTokentroller(address newTokentroller) external virtual {
        require(msg.sender == owner, "Only the owner can call this function");
        require(newTokentroller != address(0), "New tokentroller address cannot be zero");
        require(newTokentroller != address(this), "New tokentroller address cannot be the same as the current address");
        TokenMetadata(tokenMetadata).updateTokentroller(newTokentroller);
    }

    /**********************************************************************************************
     * @dev Updates the owner of the Tokentroller contract
     * @param newOwner The address of the new owner
     * @notice This function can only be called by the current owner
     * @notice The new owner address must not be zero
     * @notice Emits an OwnerUpdated event upon successful update
     *********************************************************************************************/
    function updateOwner(address newOwner) external virtual {
        require(msg.sender == owner, "Only owner can update");
        require(newOwner != address(0), "TokentrollerV1: owner cannot be zero address");
        require(newOwner != owner, "New owner must be different from current owner");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnerUpdated(oldOwner, newOwner);
    }

    /**********************************************************************************************
     * @dev Adds a trusted helper to the Tokentroller contract
     * @param helper The address of the helper to be added
     * @notice This function can only be called by the current owner
     * @notice The helper address must not be zero
     * @notice Emits a TrustedHelperAdded event upon successful addition
     *********************************************************************************************/
    function addTrustedHelper(address helper) external {
        require(msg.sender == owner, "Only owner can add trusted helpers");
        require(helper != address(0), "Helper address cannot be zero");
        trustedHelpers[helper] = true;
        emit TrustedHelperAdded(helper);
    }

    /**********************************************************************************************
     * @dev Removes a trusted helper from the Tokentroller contract
     * @param helper The address of the helper to be removed
     * @notice This function can only be called by the current owner
     * @notice The helper address must not be zero
     * @notice Emits a TrustedHelperRemoved event upon successful removal
     *********************************************************************************************/
    function removeTrustedHelper(address helper) external {
        require(msg.sender == owner, "Only owner can remove trusted helpers");
        require(helper != address(0), "Helper address cannot be zero");
        trustedHelpers[helper] = false;
        emit TrustedHelperRemoved(helper);
    }

    /**********************************************************************************************
     *  _   _             _
     * | | | | ___   ___ | | _____
     * | |_| |/ _ \ / _ \| |/ / __|
     * |  _  | (_) | (_) |   <\__ \
     * |_| |_|\___/ \___/|_|\_\___/
     *
     * @dev group of hooks that are called by the TokenRegistry contract when the corresponding
     * functions are called.
     * This can enable the tokentroller to implement any necessary checks before allowing
     * the token registry to be updated.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Checks if a token can be approved
     * @param sender The address of the sender
     * @param contractAddress The address of the token to potentially approve
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing approval
     * @return bool Returns true if the token can be approved, false otherwise
     *********************************************************************************************/
    function canApproveToken(address sender, address contractAddress) external view virtual returns (bool) {
        return sender == owner || trustedHelpers[sender];
    }

    /**********************************************************************************************
     * @dev Checks if a token can be rejected
     * @param sender The address of the sender
     * @param contractAddress The address of the token to potentially reject
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing rejection
     * @return bool Returns true if the token can be rejected, false otherwise
     *********************************************************************************************/
    function canRejectToken(address sender, address contractAddress) external view virtual returns (bool) {
        return sender == owner || trustedHelpers[sender];
    }

    /**********************************************************************************************
     * @dev Checks if a new token can be added to the registry
     * @param sender The address of the sender
     * @param contractAddress The address of the new token to be added
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing token addition
     * @return bool Returns true if the token can be added, false otherwise
     *********************************************************************************************/
    function canAddToken(address sender, address contractAddress) external view virtual returns (bool) {
        return true;
    }

    /**********************************************************************************************
     * @dev Checks if a new token can be added to the registry
     * @param sender The address of the sender
     * @param contractAddress The address of the new token to be added
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing token addition
     * @return bool Returns true if the token can be added, false otherwise
     *********************************************************************************************/
    function canUpdateToken(address sender, address contractAddress) external view virtual returns (bool) {
        TokenRegistry registry = TokenRegistry(tokenRegistry);
        TokenStatus status = registry.tokenStatus(contractAddress);
        return sender == tokenEdits && status == TokenStatus.APPROVED;
    }

    /**********************************************************************************************
     * @dev Checks if a token in the registry can be updated
     * @param sender The address of the sender
     * @param contractAddress The address of the token to update
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing token updates
     * @return bool Returns true if the token can be updated, false otherwise
     *********************************************************************************************/
    function canProposeTokenEdit(address sender, address contractAddress) external view virtual returns (bool) {
        // Check if the token is approved
        return TokenRegistry(tokenRegistry).tokenStatus(contractAddress) == TokenStatus.APPROVED;
    }

    /**********************************************************************************************
     * @dev Checks if a token edit can be accepted
     * @param sender The address of the sender
     * @param contractAddress The address of the token for which the edit is proposed
     * @param editId The id of the edit to be accepted
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing edit acceptance
     * @return bool Returns true if the edit can be accepted, false otherwise
     *********************************************************************************************/
    function canAcceptTokenEdit(
        address sender,
        address contractAddress,
        uint256 editId
    ) external view virtual returns (bool) {
        return sender == owner || trustedHelpers[sender];
    }

    /**********************************************************************************************
     * @dev Checks if a token edit can be rejected
     * @param sender The address of the sender
     * @param contractAddress The address of the token for which the edit is proposed
     * @param editId The id of the edit to be rejected
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing edit rejection
     * @return bool Returns true if the edit can be rejected, false otherwise
     *********************************************************************************************/
    function canRejectTokenEdit(
        address sender,
        address contractAddress,
        uint256 editId
    ) external view virtual returns (bool) {
        return sender == owner || trustedHelpers[sender];
    }

    /**********************************************************************************************
     * @dev Checks if a metadata field can be added
     * @param sender The address of the sender
     * @param name The name of the metadata field
     * @notice This function is called by the TokenMetadata contract
     * @notice It should implement any necessary checks before allowing metadata field addition
     * @return bool Returns true if the metadata field can be added, false otherwise
     *********************************************************************************************/
    function canAddMetadataField(address sender, string calldata name) external view virtual returns (bool) {
        return sender == owner || trustedHelpers[sender];
    }

    /**********************************************************************************************
     * @dev Checks if a metadata field can be updated
     * @param _sender The address of the sender
     * @param name The name of the metadata field
     * @param isActive The status of the metadata field
     * @param isRequired The required status of the metadata field
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing metadata field updates
     * @return bool Returns true if the metadata field can be updated, false otherwise
     *********************************************************************************************/
    function canUpdateMetadataField(
        address sender,
        string calldata name,
        bool isActive,
        bool isRequired
    ) external view virtual returns (bool) {
        return sender == owner || trustedHelpers[sender];
    }

    /**********************************************************************************************
     * @dev Checks if a metadata can be updated
     * @param sender The address of the sender
     * @param contractAddress The address of the new token to be added
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing token addition
     * @return bool Returns true if the token can be added, false otherwise
     *********************************************************************************************/
    function canUpdateMetadata(address sender, address contractAddress) external view virtual returns (bool) {
        return sender == tokenRegistry || sender == tokenEdits;
    }
}
