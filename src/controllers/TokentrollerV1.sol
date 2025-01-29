// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ITokentroller.sol";
import "../interfaces/ITokenRegistry.sol";
import "../TokenRegistry.sol";
import "../TokenMetadata.sol";
import "../TokenEdits.sol";

contract TokentrollerV1 is ITokentroller {
    address public tokenRegistry;
    address public tokenEdits;
    address public tokenMetadata;
    address public owner;

    /**********************************************************************************************
     * @dev Constructor for the Tokentroller contract
     * @param _owner The address of the contract owner
     *********************************************************************************************/
    constructor(address _owner) {
        owner = _owner;
        tokenMetadata = address(new TokenMetadata(address(this)));
        tokenRegistry = address(new TokenRegistry(address(this), tokenMetadata));
        tokenEdits = address(new TokenEdits(address(this), tokenMetadata));
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
    function updateRegistryTokentroller(address newTokentroller) public {
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
    function updateMetadataTokentroller(address newTokentroller) public {
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
    function updateOwner(address newOwner) public {
        require(msg.sender == owner, "Only the owner can call this function");
        require(newOwner != address(0), "New owner address cannot be zero");
        require(newOwner != owner, "New owner must be different from current owner");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnerUpdated(oldOwner, newOwner);
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
    function canApproveToken(address sender, address contractAddress) public view virtual returns (bool) {
        return sender == owner;
    }

    /**********************************************************************************************
     * @dev Checks if a token can be rejected
     * @param sender The address of the sender
     * @param contractAddress The address of the token to potentially reject
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing rejection
     * @return bool Returns true if the token can be rejected, false otherwise
     *********************************************************************************************/
    function canRejectToken(address sender, address contractAddress) public view virtual returns (bool) {
        return sender == owner;
    }

    /**********************************************************************************************
     * @dev Checks if a new token can be added to the registry
     * @param sender The address of the sender
     * @param contractAddress The address of the new token to be added
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing token addition
     * @return bool Returns true if the token can be added, false otherwise
     *********************************************************************************************/
    function canAddToken(address sender, address contractAddress) public view returns (bool) {
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
    function canUpdateToken(address sender, address contractAddress) public view returns (bool) {
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
    function canProposeTokenEdit(address sender, address contractAddress) public view returns (bool) {
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
    function canAcceptTokenEdit(address sender, address contractAddress, uint256 editId) public view returns (bool) {
        return sender == owner;
    }

    /**********************************************************************************************
     * @dev Checks if a token edit can be rejected
     * @param sender The address of the sender
     * @param contractAddress The address of the token for which the edit is proposed
     * @param editIndex The index of the edit to be rejected
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing edit rejection
     * @return bool Returns true if the edit can be rejected, false otherwise
     *********************************************************************************************/
    function canRejectTokenEdit(
        address sender,
        address contractAddress,
        uint256 editIndex
    ) external view returns (bool) {
        return sender == owner;
    }

    /**********************************************************************************************
     * @dev Checks if a metadata field can be added
     * @param sender The address of the sender
     * @param name The name of the metadata field
     * @notice This function is called by the TokenMetadata contract
     * @notice It should implement any necessary checks before allowing metadata field addition
     * @return bool Returns true if the metadata field can be added, false otherwise
     *********************************************************************************************/
    function canAddMetadataField(address sender, string calldata name) external view returns (bool) {
        return sender == owner;
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
    ) external view returns (bool) {
        return sender == owner;
    }

    /**********************************************************************************************
     * @dev Checks if a metadata field can be set
     * @param sender The address of the sender
     * @param token The address of the token
     * @param field The name of the metadata field
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing metadata field updates
     * @return bool Returns true if the metadata field can be updated, false otherwise
     *********************************************************************************************/
    function canSetMetadata(address sender, address token, string calldata field) external view returns (bool) {
        TokenRegistry registry = TokenRegistry(tokenRegistry);
        TokenStatus status = registry.tokenStatus(token);

        // Only allow setting metadata for pending or new tokens
        return status == TokenStatus.PENDING || status == TokenStatus.NONE;
    }

    /**********************************************************************************************
     * @dev Checks if a metadata edit can be proposed
     * @param sender The address of the sender
     * @param token The address of the token
     * @param updates The array of MetadataInput structs
     * @notice This function is called by the TokenMetadata contract
     * @notice This function verifies that the token is approved
     * @return bool Returns true if the metadata edit can be proposed, false otherwise
     *********************************************************************************************/
    function canProposeMetadataEdit(
        address sender,
        address token,
        MetadataInput[] calldata updates
    ) external view returns (bool) {
        // Allow anyone to propose edits for approved tokens
        return TokenRegistry(tokenRegistry).tokenStatus(token) == TokenStatus.APPROVED;
    }

    /**********************************************************************************************
     * @dev Checks if a metadata can be updated
     * @param sender The address of the sender
     * @param contractAddress The address of the new token to be added
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing token addition
     * @return bool Returns true if the token can be added, false otherwise
     *********************************************************************************************/
    function canUpdateMetadata(address sender, address contractAddress) public view returns (bool) {
        return sender == tokenRegistry || sender == tokenEdits;
    }

    /**********************************************************************************************
     * @dev Checks if a metadata edit can be accepted
     * @param sender The address of the sender
     * @param token The address of the token
     * @param editIndex The index of the edit to be accepted
     * @notice This function is called by the TokenMetadata contract
     * @notice This function verifies that the sender is the owner
     * @return bool Returns true if the metadata edit can be accepted, false otherwise
     *********************************************************************************************/
    function canAcceptMetadataEdit(address sender, address token, uint256 editIndex) external view returns (bool) {
        return sender == owner;
    }

    /**********************************************************************************************
     * @dev Checks if a metadata edit can be rejected
     * @param sender The address of the sender
     * @param token The address of the token
     * @param editIndex The index of the edit to be rejected
     * @notice This function is called by the TokenMetadata contract
     * @notice This function verifies that the sender is the owner
     * @return bool Returns true if the metadata edit can be rejected, false otherwise
     *********************************************************************************************/
    function canRejectMetadataEdit(address sender, address token, uint256 editIndex) external view returns (bool) {
        return sender == owner;
    }
}
