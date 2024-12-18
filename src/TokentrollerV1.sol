// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokentroller.sol";
import "./TokenRegistry.sol";
import "./TokenMetadataRegistry.sol";

contract TokentrollerV1 is ITokentroller {
    address public tokenRegistry;
    address public metadataRegistry;
    address public owner;

    /**********************************************************************************************
     * @dev Constructor for the Tokentroller contract
     * @param _owner The address of the contract owner
     *********************************************************************************************/
    constructor(address _owner) {
        owner = _owner;
        metadataRegistry = address(new TokenMetadataRegistry(address(this)));
        tokenRegistry = address(new TokenRegistry(address(this), metadataRegistry));
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
     * @param _newTokentroller The address of the new tokentroller
     * @notice This function can only be called by the owner
     * @notice The new tokentroller address must not be zero or the current contract address
     * @notice Calls the updateTokentroller function in the TokenRegistry contract
     *********************************************************************************************/
    function updateRegistryTokentroller(address _newTokentroller) public {
        require(msg.sender == owner, "Only the owner can call this function");
        require(_newTokentroller != address(0), "New tokentroller address cannot be zero");
        require(
            _newTokentroller != address(this),
            "New tokentroller address cannot be the same as the current address"
        );
        TokenRegistry(tokenRegistry).updateTokentroller(_newTokentroller);
    }

    /**********************************************************************************************
     * @dev Updates the tokentroller address in the TokenMetadataRegistry contract
     * @param _newTokentroller The address of the new tokentroller
     * @notice This function can only be called by the owner
     * @notice The new tokentroller address must not be zero or the current contract address
     * @notice Calls the updateTokentroller function in the TokenRegistry contract
     *********************************************************************************************/
    function updateMetadataRegistryTokentroller(address _newTokentroller) public {
        require(msg.sender == owner, "Only the owner can call this function");
        require(_newTokentroller != address(0), "New tokentroller address cannot be zero");
        require(
            _newTokentroller != address(this),
            "New tokentroller address cannot be the same as the current address"
        );
        TokenMetadataRegistry(metadataRegistry).updateTokentroller(_newTokentroller);
    }

    /**********************************************************************************************
     * @dev Updates the owner of the Tokentroller contract
     * @param _newOwner The address of the new owner
     * @notice This function can only be called by the current owner
     * @notice The new owner address must not be zero
     * @notice Emits an OwnerUpdated event upon successful update
     *********************************************************************************************/
    function updateOwner(address _newOwner) public {
        require(msg.sender == owner, "Only the owner can call this function");
        require(_newOwner != address(0), "New owner address cannot be zero");
        require(_newOwner != owner, "New owner must be different from current owner");
        address oldOwner = owner;
        owner = _newOwner;
        emit OwnerUpdated(oldOwner, _newOwner);
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
     * @dev Checks if a token can be fast-tracked for approval
     * @param _contractAddress The address of the token to potentially fast-track
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing fast-tracking
     * @return bool Returns true if the token can be fast-tracked, false otherwise
     *********************************************************************************************/
    function canFastTrackToken(address _sender, address _contractAddress, uint256 _chainID) public view returns (bool) {
        require(_sender == owner, "Only the owner can call this function");
        return true;
    }

    /**********************************************************************************************
     * @dev Checks if a token can be rejected
     * @param _contractAddress The address of the token to potentially reject
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing rejection
     * @return bool Returns true if the token can be rejected, false otherwise
     *********************************************************************************************/
    function canRejectToken(address _sender, address _contractAddress, uint256 _chainID) public view returns (bool) {
        require(_sender == owner, "Only the owner can call this function");
        return true;
    }

    /**********************************************************************************************
     * @dev Checks if a new token can be added to the registry
     * @param _contractAddress The address of the new token to be added
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing token addition
     * @return bool Returns true if the token can be added, false otherwise
     *********************************************************************************************/
    function canAddToken(address _contractAddress, uint256 _chainID) public view returns (bool) {
        return true;
    }

    /**********************************************************************************************
     * @dev Checks if a token in the registry can be updated
     * @param _contractAddress The address of the token to update
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing token updates
     * @return bool Returns true if the token can be updated, false otherwise
     *********************************************************************************************/
    function canProposeTokenEdit(address _contractAddress, uint256 _chainID) public view returns (bool) {
        return true;
    }

    /**********************************************************************************************
     * @dev Checks if a token edit can be accepted
     * @param _contractAddress The address of the token for which the edit is proposed
     * @param _editIndex The index of the edit to be accepted
     * @notice This function is called by the TokenRegistry contract
     * @notice It should implement any necessary checks before allowing edit acceptance
     * @return bool Returns true if the edit can be accepted, false otherwise
     *********************************************************************************************/
    function canAcceptTokenEdit(
        address _contractAddress,
        uint256 _chainID,
        uint256 _editIndex
    ) public view returns (bool) {
        return true;
    }

    function canAddMetadataField(address sender, string calldata name) external view returns (bool) {
        return sender == owner;
    }

    function canUpdateMetadataField(address sender, string calldata name, bool isActive) external view returns (bool) {
        return sender == owner;
    }

    // FIXME: check if method is safe
    function canSetMetadata(
        address sender,
        address token,
        uint256 chainID,
        string calldata field
    ) external view returns (bool) {
        TokenRegistry registry = TokenRegistry(tokenRegistry);
        // Check pending tokens first
        (address contractAddress, address submitter, , , , , ) = registry.tokens(chainID, token, 0);
        if (submitter == sender) return true;

        // Check approved tokens
        (contractAddress, submitter, , , , , ) = registry.tokens(chainID, token, 1);
        if (contractAddress != address(0)) {
            // Token is approved, only allow edits through proposal system
            return false;
        }

        // Allow new token submissions
        return submitter == address(0);
    }

    function canProposeMetadataEdit(
        address sender,
        address token,
        uint256 chainID,
        MetadataInput[] calldata updates
    ) external view returns (bool) {
        // Allow anyone to propose edits for approved tokens
        TokenRegistry registry = TokenRegistry(tokenRegistry);
        (address contractAddress, , , , , , ) = registry.tokens(chainID, token, 1);
        return contractAddress != address(0);
    }

    function canAcceptMetadataEdit(
        address sender,
        address token,
        uint256 chainID,
        uint256 editIndex
    ) external view returns (bool) {
        return sender == owner;
    }

    function canRejectTokenEdit(
        address sender,
        address token,
        uint256 chainID,
        uint256 editIndex
    ) external view returns (bool) {
        return sender == owner;
    }
}
