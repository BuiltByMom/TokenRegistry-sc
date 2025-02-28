// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TokentrollerV1Update.sol";
import "@hyperlane/interfaces/IMailbox.sol";
import "@hyperlane/hooks/libs/StandardHookMetadata.sol";
import "../libraries/Commands.sol";

/**********************************************************************************************
 * @title HyperlaneRootPlugin
 * @dev A plugin for TokentrollerV1 that enables cross-chain token registry operations
 * through Hyperlane's messaging protocol. This contract acts as the root node in the
 * cross-chain system, sending commands to leaf chains.
 *********************************************************************************************/
contract HyperlaneRootPlugin is TokentrollerV1Update {
    using Commands for uint256;

    // Hyperlane mailbox contract for cross-chain messaging
    IMailbox public immutable mailbox;

    // Mapping of child chain IDs to their Tokentroller addresses
    mapping(uint256 => address) public leafs;

    /**********************************************************************************************
     *  ______               _
     * |  ____|             | |
     * | |____   _____ _ __ | |_ ___
     * |  __\ \ / / _ \ '_ \| __/ __|
     * | |___\ V /  __/ | | | |_\__ \
     * |______\_/ \___|_| |_|\__|___/
     *
     * @notice Events emitted by the root plugin
     *********************************************************************************************/
    event MessageSent(bytes32 messageId, uint32 destinationDomain, bytes32 recipient, bytes message);
    event LeafSet(uint256 indexed chainId, address indexed leaf);
    event CrossChainTokenApproved(uint256 indexed chainId, address indexed token);
    event CrossChainTokenRejected(uint256 indexed chainId, address indexed token, string reason);
    event CrossChainTokenEditAccepted(uint256 indexed chainId, address indexed token, uint256 indexed editId);
    event CrossChainTokenEditRejected(
        uint256 indexed chainId,
        address indexed token,
        uint256 indexed editId,
        string reason
    );
    event CrossChainMetadataFieldAdded(uint256 indexed chainId, string indexed name, bool isRequired);
    event CrossChainMetadataFieldUpdated(uint256 indexed chainId, string indexed name, bool isActive, bool isRequired);
    event CrossChainRegistryTokentrollerUpdated(uint256 indexed chainId, address indexed newTokentroller);
    event CrossChainTokenEditsUpdated(uint256 indexed chainId, address indexed newTokenEdits);
    event CrossChainOwnerUpdated(uint256 indexed chainId, address indexed newOwner);

    /**********************************************************************************************
     * @dev Constructor for the HyperlaneRootPlugin contract
     * @param _owner The address of the contract owner
     * @param _mailbox The address of the Hyperlane mailbox contract
     * @notice Initializes the contract with the owner and mailbox addresses
     *********************************************************************************************/
    constructor(
        address _owner,
        address _mailbox,
        address _tokenMetadata,
        address _tokenRegistry,
        address _tokenEdits
    ) TokentrollerV1Update(_owner, _tokenMetadata, _tokenRegistry, _tokenEdits) {
        mailbox = IMailbox(_mailbox);
    }

    /**********************************************************************************************
     * @dev Calculates the message fee for a cross-chain operation
     * @param destinationDomain The domain ID of the destination chain
     * @param messageBody The encoded message to be sent
     * @param command The command type being executed
     * @param customGasLimit Optional custom gas limit for the operation
     * @notice Returns the required message fee in native tokens
     * @notice Uses StandardHookMetadata for message formatting
     *********************************************************************************************/
    function quote(
        uint256 destinationDomain,
        bytes calldata messageBody,
        uint256 command,
        uint256 customGasLimit
    ) public view returns (uint256) {
        bytes memory metadata = StandardHookMetadata.formatMetadata({
            _msgValue: 0,
            _gasLimit: command.gasLimit(customGasLimit),
            _refundAddress: msg.sender,
            _customMetadata: ""
        });

        return
            mailbox.quoteDispatch({
                destinationDomain: uint32(destinationDomain),
                recipientAddress: bytes32(uint256(uint160(address(this)))),
                messageBody: messageBody,
                defaultHookMetadata: metadata
            });
    }

    /**********************************************************************************************
     * @dev Calculates the message fee for a cross-chain operation with default gas limit
     * @param destinationDomain The domain ID of the destination chain
     * @param messageBody The encoded message to be sent
     * @param command The command type being executed
     * @notice Returns the required message fee in native tokens
     * @notice Uses the default gas limit for the command type
     *********************************************************************************************/
    function quote(
        uint256 destinationDomain,
        bytes calldata messageBody,
        uint256 command
    ) external view returns (uint256) {
        return quote(destinationDomain, messageBody, command, 0);
    }

    /**********************************************************************************************
     * @dev Internal function to send a cross-chain message
     * @param destinationChainId The ID of the destination chain
     * @param target The address of the target contract on the destination chain
     * @param message The encoded message to be sent
     * @param command The command type being executed
     * @param customGasLimit Optional custom gas limit for the operation
     * @notice Sends the message through the Hyperlane mailbox
     * @notice Emits a MessageSent event on success
     *********************************************************************************************/
    function sendMessage(
        uint256 destinationChainId,
        address target,
        bytes memory message,
        uint256 command,
        uint256 customGasLimit
    ) internal {
        bytes32 recipient = bytes32(uint256(uint160(target)));

        bytes memory metadata = StandardHookMetadata.formatMetadata({
            _msgValue: msg.value,
            _gasLimit: command.gasLimit(customGasLimit),
            _refundAddress: msg.sender,
            _customMetadata: ""
        });

        bytes32 messageId = mailbox.dispatch{ value: msg.value }(
            uint32(destinationChainId),
            recipient,
            message,
            metadata
        );

        emit MessageSent(messageId, uint32(destinationChainId), recipient, message);
    }

    /**********************************************************************************************
     * @dev Sets the leaf contract address for a chain
     * @param chainId The ID of the chain to set the leaf for
     * @param leaf The address of the leaf contract
     * @notice This function can only be called by the owner
     * @notice The leaf address cannot be zero
     * @notice Emits a LeafSet event on success
     *********************************************************************************************/
    function setLeaf(uint256 chainId, address leaf) external {
        require(msg.sender == owner, "Only owner can set leaf");
        require(leaf != address(0), "Invalid leaf address");
        leafs[chainId] = leaf;
        emit LeafSet(chainId, leaf);
    }

    /**********************************************************************************************
     * @dev Updates the registry tokentroller on a leaf chain
     * @param chainId The ID of the chain to update
     * @param newTokentroller The address of the new tokentroller
     * @param customGasLimit Optional custom gas limit for the operation
     * @notice This function can only be called by the owner
     * @notice The new tokentroller address cannot be zero
     * @notice Emits a CrossChainRegistryTokentrollerUpdated event on success
     *********************************************************************************************/
    function updateRegistryTokentroller(
        uint256 chainId,
        address newTokentroller,
        uint256 customGasLimit
    ) public payable {
        require(msg.sender == owner, "Only owner can update registry tokentroller");
        require(newTokentroller != address(0), "New tokentroller address cannot be zero");

        bytes memory message = abi.encodeWithSignature("updateRegistryTokentroller(address)", newTokentroller);

        sendMessage(chainId, leafs[chainId], message, Commands.UPDATE_REGISTRY_TOKENTROLLER, customGasLimit);

        emit CrossChainRegistryTokentrollerUpdated(chainId, newTokentroller);
    }

    /**********************************************************************************************
     * @dev Updates the registry tokentroller on a leaf chain with default gas limit
     * @param chainId The ID of the chain to update
     * @param newTokentroller The address of the new tokentroller
     * @notice This function can only be called by the owner
     * @notice Uses the default gas limit for the operation
     *********************************************************************************************/
    function updateRegistryTokentroller(uint256 chainId, address newTokentroller) external payable {
        updateRegistryTokentroller(chainId, newTokentroller, 0);
    }

    /**********************************************************************************************
     * @dev Updates the token edits on a leaf chain
     * @param chainId The ID of the chain to update
     * @param newTokenEdits The address of the new token edits
     * @param customGasLimit Optional custom gas limit for the operation
     * @notice This function can only be called by the owner
     * @notice The new token edits address cannot be zero
     * @notice Emits a CrossChainTokenEditsUpdated event on success
     *********************************************************************************************/
    function updateTokenEdits(uint256 chainId, address newTokenEdits, uint256 customGasLimit) public payable {
        require(msg.sender == owner, "Only owner can update token edits");
        require(newTokenEdits != address(0), "New token edits address cannot be zero");

        bytes memory message = abi.encodeWithSignature("updateTokenEdits(address)", newTokenEdits);

        sendMessage(chainId, leafs[chainId], message, Commands.UPDATE_TOKEN_EDITS, customGasLimit);

        emit CrossChainTokenEditsUpdated(chainId, newTokenEdits);
    }

    /**********************************************************************************************
     * @dev Updates the token edits on a leaf chain with default gas limit
     * @param chainId The ID of the chain to update
     * @param newTokenEdits The address of the new token edits
     * @notice This function can only be called by the owner
     * @notice Uses the default gas limit for the operation
     *********************************************************************************************/
    function updateTokenEdits(uint256 chainId, address newTokenEdits) external payable {
        updateTokenEdits(chainId, newTokenEdits, 0);
    }

    /**********************************************************************************************
     * @dev Updates the owner on a leaf chain
     * @param chainId The ID of the chain to update
     * @param newOwner The address of the new owner
     * @param customGasLimit Optional custom gas limit for the operation
     * @notice This function can only be called by the owner
     * @notice The new owner address cannot be zero
     * @notice Emits a CrossChainOwnerUpdated event on success
     *********************************************************************************************/
    function updateOwner(uint256 chainId, address newOwner, uint256 customGasLimit) public payable {
        require(msg.sender == owner, "Only owner can update owner");
        require(newOwner != address(0), "New owner address cannot be zero");

        bytes memory message = abi.encodeWithSignature("updateOwner(address)", newOwner);

        sendMessage(chainId, leafs[chainId], message, Commands.UPDATE_OWNER, customGasLimit);

        emit CrossChainOwnerUpdated(chainId, newOwner);
    }

    /**********************************************************************************************
     * @dev Updates the owner on a leaf chain with default gas limit
     * @param chainId The ID of the chain to update
     * @param newOwner The address of the new owner
     * @notice This function can only be called by the owner
     * @notice Uses the default gas limit for the operation
     *********************************************************************************************/
    function updateOwner(uint256 chainId, address newOwner) external payable {
        updateOwner(chainId, newOwner, 0);
    }

    /**********************************************************************************************
     * @dev Approves a token on a leaf chain
     * @param chainId The ID of the chain to approve the token on
     * @param token The address of the token to approve
     * @param customGasLimit Optional custom gas limit for the operation
     * @notice This function can only be called by the owner
     * @notice The leaf must be set for the chain
     * @notice Emits a CrossChainTokenApproved event on success
     *********************************************************************************************/
    function approveTokenOnLeaf(uint256 chainId, address token, uint256 customGasLimit) public payable {
        require(msg.sender == owner, "Only owner can approve tokens");
        require(leafs[chainId] != address(0), "Leaf not set");

        bytes memory message = abi.encodeWithSignature("executeApproveToken(address)", token);

        sendMessage(chainId, leafs[chainId], message, Commands.APPROVE_TOKEN, customGasLimit);

        emit CrossChainTokenApproved(chainId, token);
    }

    /**********************************************************************************************
     * @dev Approves a token on a leaf chain with default gas limit
     * @param chainId The ID of the chain to approve the token on
     * @param token The address of the token to approve
     * @notice This function can only be called by the owner
     * @notice Uses the default gas limit for the operation
     *********************************************************************************************/
    function approveTokenOnLeaf(uint256 chainId, address token) external payable {
        approveTokenOnLeaf(chainId, token, 0);
    }

    /**********************************************************************************************
     * @dev Rejects a token on a leaf chain
     * @param chainId The ID of the chain to reject the token on
     * @param token The address of the token to reject
     * @param reason The reason for rejecting the token
     * @param customGasLimit Optional custom gas limit for the operation
     * @notice This function can only be called by the owner
     * @notice The leaf must be set for the chain
     * @notice Emits a CrossChainTokenRejected event on success
     *********************************************************************************************/
    function rejectTokenOnLeaf(
        uint256 chainId,
        address token,
        string calldata reason,
        uint256 customGasLimit
    ) public payable {
        require(msg.sender == owner, "Only owner can reject tokens");
        require(leafs[chainId] != address(0), "Leaf not set");

        bytes memory message = abi.encodeWithSignature("executeRejectToken(address,string)", token, reason);

        sendMessage(chainId, leafs[chainId], message, Commands.REJECT_TOKEN, customGasLimit);

        emit CrossChainTokenRejected(chainId, token, reason);
    }

    /**********************************************************************************************
     * @dev Rejects a token on a leaf chain with default gas limit
     * @param chainId The ID of the chain to reject the token on
     * @param token The address of the token to reject
     * @param reason The reason for rejecting the token
     * @notice This function can only be called by the owner
     * @notice Uses the default gas limit for the operation
     *********************************************************************************************/
    function rejectTokenOnLeaf(uint256 chainId, address token, string calldata reason) external payable {
        rejectTokenOnLeaf(chainId, token, reason, 0);
    }

    /**********************************************************************************************
     * @dev Accepts a token edit on a leaf chain
     * @param chainId The ID of the chain to accept the edit on
     * @param token The address of the token whose edit is being accepted
     * @param editId The ID of the edit to accept
     * @param customGasLimit Optional custom gas limit for the operation
     * @notice This function can only be called by the owner
     * @notice The leaf must be set for the chain
     * @notice Emits a CrossChainTokenEditAccepted event on success
     *********************************************************************************************/
    function acceptTokenEditOnLeaf(
        uint256 chainId,
        address token,
        uint256 editId,
        uint256 customGasLimit
    ) public payable {
        require(msg.sender == owner, "Only owner can accept token edits");
        require(leafs[chainId] != address(0), "Leaf not set");

        bytes memory message = abi.encodeWithSignature("executeAcceptTokenEdit(address,uint256)", token, editId);

        sendMessage(chainId, leafs[chainId], message, Commands.ACCEPT_TOKEN_EDIT, customGasLimit);

        emit CrossChainTokenEditAccepted(chainId, token, editId);
    }

    /**********************************************************************************************
     * @dev Accepts a token edit on a leaf chain with default gas limit
     * @param chainId The ID of the chain to accept the edit on
     * @param token The address of the token whose edit is being accepted
     * @param editId The ID of the edit to accept
     * @notice This function can only be called by the owner
     * @notice Uses the default gas limit for the operation
     *********************************************************************************************/
    function acceptTokenEditOnLeaf(uint256 chainId, address token, uint256 editId) external payable {
        acceptTokenEditOnLeaf(chainId, token, editId, 0);
    }

    /**********************************************************************************************
     * @dev Rejects a token edit on a leaf chain
     * @param chainId The ID of the chain to reject the edit on
     * @param token The address of the token whose edit is being rejected
     * @param editId The ID of the edit to reject
     * @param reason The reason for rejecting the edit
     * @param customGasLimit Optional custom gas limit for the operation
     * @notice This function can only be called by the owner
     * @notice The leaf must be set for the chain
     * @notice Emits a CrossChainTokenEditRejected event on success
     *********************************************************************************************/
    function rejectTokenEditOnLeaf(
        uint256 chainId,
        address token,
        uint256 editId,
        string calldata reason,
        uint256 customGasLimit
    ) public payable {
        require(msg.sender == owner, "Only owner can reject token edits");
        require(leafs[chainId] != address(0), "Leaf not set");

        bytes memory message = abi.encodeWithSignature(
            "executeRejectTokenEdit(address,uint256,string)",
            token,
            editId,
            reason
        );

        sendMessage(chainId, leafs[chainId], message, Commands.REJECT_TOKEN_EDIT, customGasLimit);

        emit CrossChainTokenEditRejected(chainId, token, editId, reason);
    }

    /**********************************************************************************************
     * @dev Rejects a token edit on a leaf chain with default gas limit
     * @param chainId The ID of the chain to reject the edit on
     * @param token The address of the token whose edit is being rejected
     * @param editId The ID of the edit to reject
     * @param reason The reason for rejecting the edit
     * @notice This function can only be called by the owner
     * @notice Uses the default gas limit for the operation
     *********************************************************************************************/
    function rejectTokenEditOnLeaf(
        uint256 chainId,
        address token,
        uint256 editId,
        string calldata reason
    ) external payable {
        rejectTokenEditOnLeaf(chainId, token, editId, reason, 0);
    }

    /**********************************************************************************************
     * @dev Adds a metadata field on a leaf chain
     * @param chainId The ID of the chain to add the field on
     * @param name The name of the metadata field to add
     * @param isRequired Whether the field should be required
     * @param customGasLimit Optional custom gas limit for the operation
     * @notice This function can only be called by the owner
     * @notice The leaf must be set for the chain
     * @notice Emits a CrossChainMetadataFieldAdded event on success
     *********************************************************************************************/
    function addMetadataFieldOnLeaf(
        uint256 chainId,
        string calldata name,
        bool isRequired,
        uint256 customGasLimit
    ) public payable {
        require(msg.sender == owner, "Only owner can add metadata fields");
        require(leafs[chainId] != address(0), "Leaf not set");

        bytes memory message = abi.encodeWithSignature("executeAddMetadataField(string,bool)", name, isRequired);

        sendMessage(chainId, leafs[chainId], message, Commands.ADD_METADATA_FIELD, customGasLimit);

        emit CrossChainMetadataFieldAdded(chainId, name, isRequired);
    }

    /**********************************************************************************************
     * @dev Adds a metadata field on a leaf chain with default gas limit
     * @param chainId The ID of the chain to add the field on
     * @param name The name of the metadata field to add
     * @param isRequired Whether the field should be required
     * @notice This function can only be called by the owner
     * @notice Uses the default gas limit for the operation
     *********************************************************************************************/
    function addMetadataFieldOnLeaf(uint256 chainId, string calldata name, bool isRequired) external payable {
        addMetadataFieldOnLeaf(chainId, name, isRequired, 0);
    }

    /**********************************************************************************************
     * @dev Updates a metadata field on a leaf chain
     * @param chainId The ID of the chain to update the field on
     * @param name The name of the metadata field to update
     * @param isActive Whether the field should be active
     * @param isRequired Whether the field should be required
     * @param customGasLimit Optional custom gas limit for the operation
     * @notice This function can only be called by the owner
     * @notice The leaf must be set for the chain
     * @notice Emits a CrossChainMetadataFieldUpdated event on success
     *********************************************************************************************/
    function updateMetadataFieldOnLeaf(
        uint256 chainId,
        string calldata name,
        bool isActive,
        bool isRequired,
        uint256 customGasLimit
    ) public payable {
        require(msg.sender == owner, "Only owner can update metadata fields");
        require(leafs[chainId] != address(0), "Leaf not set");

        bytes memory message = abi.encodeWithSignature(
            "executeUpdateMetadataField(string,bool,bool)",
            name,
            isActive,
            isRequired
        );

        sendMessage(chainId, leafs[chainId], message, Commands.UPDATE_METADATA_FIELD, customGasLimit);

        emit CrossChainMetadataFieldUpdated(chainId, name, isActive, isRequired);
    }

    /**********************************************************************************************
     * @dev Updates a metadata field on a leaf chain with default gas limit
     * @param chainId The ID of the chain to update the field on
     * @param name The name of the metadata field to update
     * @param isActive Whether the field should be active
     * @param isRequired Whether the field should be required
     * @notice This function can only be called by the owner
     * @notice Uses the default gas limit for the operation
     *********************************************************************************************/
    function updateMetadataFieldOnLeaf(
        uint256 chainId,
        string calldata name,
        bool isActive,
        bool isRequired
    ) external payable {
        updateMetadataFieldOnLeaf(chainId, name, isActive, isRequired, 0);
    }
}
