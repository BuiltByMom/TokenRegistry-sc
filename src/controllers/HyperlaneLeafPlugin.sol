// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TokentrollerV1Update.sol";
import "@hyperlane/interfaces/IMailbox.sol";

/**********************************************************************************************
 * @title HyperlaneLeafPlugin
 * @dev A plugin for TokentrollerV1 that enables cross-chain token registry operations
 * through Hyperlane's messaging protocol. This contract acts as a leaf node in the
 * cross-chain system, receiving and executing commands from the root chain.
 *********************************************************************************************/
contract HyperlaneLeafPlugin is TokentrollerV1Update {
    address public immutable root;

    // Hyperlane mailbox contract for cross-chain messaging
    IMailbox public immutable mailbox;

    // Flag to track if we're executing a cross-chain message
    bool private executingCrossChainMessage;

    // Current message context
    address private currentSender;
    uint256 private currentSourceChain;
    bytes32 private currentMessageId;

    /**********************************************************************************************
     *  ______               _
     * |  ____|             | |
     * | |____   _____ _ __ | |_ ___
     * |  __\ \ / / _ \ '_ \| __/ __|
     * | |___\ V /  __/ | | | |_\__ \
     * |______\_/ \___|_| |_|\__|___/
     *
     * @notice Events emitted by the leaf plugin
     *********************************************************************************************/
    event CrossChainMessageExecuted(bytes32 indexed messageId, bytes message);
    event CrossChainMessageFailed(bytes32 indexed messageId, string reason);

    /**********************************************************************************************
     *  _____                _                   _
     * / ____|              | |                 | |
     *| |     ___  _ __  ___| |_ _ __ _   _  ___| |_ ___  _ __
     *| |    / _ \| '_ \/ __| __| '__| | | |/ __| __/ _ \| '__|
     *| |___| (_) | | | \__ \ |_| |  | |_| | (__| || (_) | |
     * \_____\___/|_| |_|___/\__|_|   \__,_|\___|\__\___/|_|
     *
     * @notice Constructor for the HyperlaneLeafPlugin contract
     * @param _owner The address of the contract owner
     * @param _root The address of the root contract on the root chain
     * @param _mailbox The address of the Hyperlane mailbox contract
     *********************************************************************************************/
    constructor(
        address _owner,
        address _root,
        address _mailbox,
        address _tokenMetadata,
        address _tokenRegistry,
        address _tokenEdits
    ) TokentrollerV1Update(_owner, _tokenMetadata, _tokenRegistry, _tokenEdits) {
        require(_root != address(0), "HyperlaneLeafPlugin: root cannot be zero address");
        require(_mailbox != address(0), "HyperlaneLeafPlugin: mailbox cannot be zero address");
        root = _root;
        mailbox = IMailbox(_mailbox);
    }

    /**********************************************************************************************
     *  __  __           _ _  __ _
     * |  \/  |         | (_)/ _(_)
     * | \  / | ___   __| |_| |_ _  ___ _ __ ___
     * | |\/| |/ _ \ / _` | |  _| |/ _ \ '__/ __|
     * | |  | | (_) | (_| | | | | |  __/ |  \__ \
     * |_|  |_|\___/ \__,_|_|_| |_|\___|_|  |___/
     *
     * @notice Modifiers used in the contract
     *********************************************************************************************/
    modifier onlyFromRoot() {
        require(messageSender() == root, "Only root can call");
        _;
    }

    modifier crossChainContext() {
        require(!executingCrossChainMessage, "Already executing cross-chain message");
        executingCrossChainMessage = true;
        _;
        executingCrossChainMessage = false;
    }

    /**********************************************************************************************
     *  _   _ _   _ _ _ _
     * | | | | |_(_) (_) |_ _   _
     * | | | | __| | | | __| | | |
     * | |_| | |_| | | | |_| |_| |
     *  \___/ \__|_|_|_|\__|\__, |
     *                      |___/
     *
     * @notice Utility functions for message handling
     *********************************************************************************************/
    function messageSender() internal view returns (address) {
        require(currentSender != address(0), "No message being processed");
        return currentSender;
    }

    function sourceChainId() external view returns (uint256) {
        require(currentSourceChain != 0, "No message being processed");
        return currentSourceChain;
    }

    /**********************************************************************************************
     *  __  __                                _   _                 _ _ _
     * |  \/  | ___  ___ ___  __ _  __ _  ___| | | | __ _ _ __   __| | (_)_ __   __ _
     * | |\/| |/ _ \/ __/ __|/ _` |/ _` |/ _ \ |_| |/ _` | '_ \ / _` | | | '_ \ / _` |
     * | |  | |  __/\__ \__ \ (_| | (_| |  __/  _  | (_| | | | | (_| | | | | | | (_| |
     * |_|  |_|\___||___/___/\__,_|\__, |\___|_| |_|\__,_|_| |_|\__,_|_|_|_| |_|\__, |
     *                             |___/                                        |___/
     * @notice Core message handling functionality
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Handles incoming cross-chain messages from the root chain
     * @param _origin The domain ID of the origin chain
     * @param _sender The address of the sender on the origin chain
     * @param _message The encoded message to be executed
     * @notice This function can only be called by the Hyperlane mailbox contract
     * @notice Sets up message context, executes the message, and cleans up context afterward
     * @notice Emits CrossChainMessageExecuted on success or CrossChainMessageFailed on failure
     *********************************************************************************************/
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external {
        require(msg.sender == address(mailbox), "Only mailbox can call handle");

        // Set message context
        currentSourceChain = _origin;
        currentSender = address(uint160(uint256(_sender)));
        currentMessageId = keccak256(_message);

        // Add revert reason
        (bool success, bytes memory returnData) = address(this).call(_message);
        require(success, "Message execution failed");

        // Clear context
        currentSender = address(0);
        currentSourceChain = 0;
        currentMessageId = bytes32(0);
    }

    /**********************************************************************************************
     *   ___                      _     _
     *  / _ \__   _____ _ __ _ __(_) __| | ___  ___
     * | | | \ \ / / _ \ '__| '__| |/ _` |/ _ \/ __|
     * | |_| |\ V /  __/ |  | |  | | (_| |  __/\__ \
     *  \___/  \_/ \___|_|  |_|  |_|\__,_|\___||___/
     *
     * @notice Override parent functions to restrict them to cross-chain execution only
     *********************************************************************************************/

    function canApproveToken(address sender, address contractAddress) public view override returns (bool) {
        return executingCrossChainMessage; // Only allow during cross-chain execution
    }

    function canRejectToken(address sender, address contractAddress) public view override returns (bool) {
        return executingCrossChainMessage; // Only allow during cross-chain execution
    }

    function canAcceptTokenEdit(
        address sender,
        address contractAddress,
        uint256 editId
    ) public view override returns (bool) {
        return executingCrossChainMessage; // Only allow during cross-chain execution
    }

    function canRejectTokenEdit(
        address sender,
        address contractAddress,
        uint256 editId
    ) public view override returns (bool) {
        return executingCrossChainMessage; // Only allow during cross-chain execution
    }

    function canAddMetadataField(address sender, string calldata name) public view override returns (bool) {
        return executingCrossChainMessage; // Only allow during cross-chain execution
    }

    function canUpdateMetadataField(
        address sender,
        string calldata name,
        bool isActive,
        bool isRequired
    ) public view override returns (bool) {
        return executingCrossChainMessage; // Only allow during cross-chain execution
    }

    /**********************************************************************************************
     *  __  __       _        _
     * |  \/  |_   _| |_ __ _| |_ ___  _ __ ___
     * | |\/| | | | | __/ _` | __/ _ \| '__/ __|
     * | |  | | |_| | || (_| | || (_) | |  \__ \
     * |_|  |_|\__,_|\__\__,_|\__\___/|_|  |___/
     *
     * @notice Cross-chain message execution functions
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Updates the tokentroller address in the TokenRegistry contract via cross-chain message
     * @param newTokentroller The address of the new tokentroller
     * @notice This function can only be called by the root chain
     * @notice The new tokentroller address must not be zero or the current contract address
     * @notice Emits CrossChainMessageExecuted on success or CrossChainMessageFailed on failure
     *********************************************************************************************/
    function updateRegistryTokentroller(address newTokentroller) external override onlyFromRoot crossChainContext {
        require(newTokentroller != address(0), "New tokentroller address cannot be zero");
        require(newTokentroller != address(this), "New tokentroller address cannot be the same as the current address");

        try TokenRegistry(tokenRegistry).updateTokentroller(newTokentroller) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory reason) {
            emit CrossChainMessageFailed(currentMessageId, reason);
            revert(reason);
        }

        try TokenEdits(tokenEdits).updateTokentroller(newTokentroller) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory reason) {
            emit CrossChainMessageFailed(currentMessageId, reason);
            revert(reason);
        }

        try TokenMetadata(tokenMetadata).updateTokentroller(newTokentroller) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory reason) {
            emit CrossChainMessageFailed(currentMessageId, reason);
            revert(reason);
        }
    }

    /**********************************************************************************************
     * @dev Updates the owner of the Tokentroller contract via cross-chain message
     * @param newOwner The address of the new owner
     * @notice This function can only be called by the root chain
     * @notice The new owner address must not be zero or the current contract address
     * @notice Emits CrossChainMessageExecuted on success
     *********************************************************************************************/
    function updateTokenEdits(address newTokenEdits) external override onlyFromRoot crossChainContext {
        require(newTokenEdits != address(0), "New token edits address cannot be zero");
        require(newTokenEdits != address(this), "New token edits address cannot be the same as the current address");

        tokenEdits = newTokenEdits;

        emit CrossChainMessageExecuted(currentMessageId, msg.data);
    }

    /**********************************************************************************************
     * @dev Updates the owner of the Tokentroller contract via cross-chain message
     * @param newOwner The address of the new owner
     * @notice This function can only be called by the root chain
     * @notice The new owner address must not be zero or the current contract address
     * @notice Emits CrossChainMessageExecuted and OwnerUpdated on success
     *********************************************************************************************/
    function updateOwner(address newOwner) external override onlyFromRoot crossChainContext {
        require(newOwner != address(0), "New owner address cannot be zero");
        require(newOwner != address(this), "New owner address cannot be the same as the current address");

        address oldOwner = owner;
        owner = newOwner;

        emit CrossChainMessageExecuted(currentMessageId, msg.data);
        emit OwnerUpdated(oldOwner, newOwner);
    }

    /**********************************************************************************************
     * @dev Approves a token in the registry via cross-chain message
     * @param token The address of the token to approve
     * @notice This function can only be called by the root chain
     * @notice Emits CrossChainMessageExecuted on success or CrossChainMessageFailed on failure
     *********************************************************************************************/
    function executeApproveToken(address token) external onlyFromRoot crossChainContext {
        try TokenRegistry(tokenRegistry).approveToken(token) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory reason) {
            emit CrossChainMessageFailed(currentMessageId, reason);
            revert(reason);
        }
    }

    /**********************************************************************************************
     * @dev Rejects a token in the registry via cross-chain message
     * @param token The address of the token to reject
     * @param reason The reason for rejecting the token
     * @notice This function can only be called by the root chain
     * @notice Emits CrossChainMessageExecuted on success or CrossChainMessageFailed on failure
     *********************************************************************************************/
    function executeRejectToken(address token, string calldata reason) external onlyFromRoot crossChainContext {
        try TokenRegistry(tokenRegistry).rejectToken(token, reason) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory revertReason) {
            emit CrossChainMessageFailed(currentMessageId, revertReason);
            revert(revertReason);
        }
    }

    /**********************************************************************************************
     * @dev Accepts a token edit proposal via cross-chain message
     * @param token The address of the token whose edit is being accepted
     * @param editId The ID of the edit to accept
     * @notice This function can only be called by the root chain
     * @notice Emits CrossChainMessageExecuted on success or CrossChainMessageFailed on failure
     *********************************************************************************************/
    function executeAcceptTokenEdit(address token, uint256 editId) external onlyFromRoot crossChainContext {
        try TokenEdits(tokenEdits).acceptEdit(token, editId) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory reason) {
            emit CrossChainMessageFailed(currentMessageId, reason);
            revert(reason);
        }
    }

    /**********************************************************************************************
     * @dev Rejects a token edit proposal via cross-chain message
     * @param token The address of the token whose edit is being rejected
     * @param editId The ID of the edit to reject
     * @param reason The reason for rejecting the edit
     * @notice This function can only be called by the root chain
     * @notice Emits CrossChainMessageExecuted on success or CrossChainMessageFailed on failure
     *********************************************************************************************/
    function executeRejectTokenEdit(
        address token,
        uint256 editId,
        string calldata reason
    ) external onlyFromRoot crossChainContext {
        try TokenEdits(tokenEdits).rejectEdit(token, editId, reason) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory revertReason) {
            emit CrossChainMessageFailed(currentMessageId, revertReason);
            revert(revertReason);
        }
    }

    /**********************************************************************************************
     * @dev Adds a new metadata field via cross-chain message
     * @param name The name of the metadata field to add
     * @param isRequired Whether the field should be required
     * @notice This function can only be called by the root chain
     * @notice Emits CrossChainMessageExecuted on success or CrossChainMessageFailed on failure
     *********************************************************************************************/
    function executeAddMetadataField(string calldata name, bool isRequired) external onlyFromRoot crossChainContext {
        try TokenMetadata(tokenMetadata).addField(name, isRequired) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory reason) {
            emit CrossChainMessageFailed(currentMessageId, reason);
            revert(reason);
        }
    }

    /**********************************************************************************************
     * @dev Updates a metadata field's properties via cross-chain message
     * @param name The name of the metadata field to update
     * @param isActive Whether the field should be active
     * @param isRequired Whether the field should be required
     * @notice This function can only be called by the root chain
     * @notice Emits CrossChainMessageExecuted on success or CrossChainMessageFailed on failure
     *********************************************************************************************/
    function executeUpdateMetadataField(
        string calldata name,
        bool isActive,
        bool isRequired
    ) external onlyFromRoot crossChainContext {
        try TokenMetadata(tokenMetadata).updateField(name, isActive, isRequired) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory reason) {
            emit CrossChainMessageFailed(currentMessageId, reason);
            revert(reason);
        }
    }
}
