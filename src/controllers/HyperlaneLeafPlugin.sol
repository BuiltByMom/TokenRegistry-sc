// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokentrollerV1.sol";
import "@hyperlane/interfaces/IMailbox.sol";

contract HyperlaneLeafPlugin is TokentrollerV1 {
    address public root;

    // Hyperlane mailbox contract
    IMailbox public immutable mailbox;

    // Flag to track if we're executing a cross-chain message
    bool private executingCrossChainMessage;

    // Current message context
    address private currentSender;
    uint256 private currentSourceChain;
    bytes32 private currentMessageId;

    event CrossChainMessageExecuted(bytes32 indexed messageId, bytes message);
    event CrossChainMessageFailed(bytes32 indexed messageId, string reason);

    constructor(address _owner, address _root, address _mailbox) TokentrollerV1(_owner) {
        root = _root;
        mailbox = IMailbox(_mailbox);
    }

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

    function messageSender() internal view returns (address) {
        require(currentSender != address(0), "No message being processed");
        return currentSender;
    }

    function sourceChainId() external view returns (uint256) {
        require(currentSourceChain != 0, "No message being processed");
        return currentSourceChain;
    }

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

    // Override parent functions to restrict them
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

    // Cross-chain message handlers
    function updateRegistryTokentroller(address newTokentroller) external override onlyFromRoot crossChainContext {
        require(newTokentroller != address(0), "New tokentroller address cannot be zero");
        require(newTokentroller != address(this), "New tokentroller address cannot be the same as the current address");

        try TokenRegistry(tokenRegistry).updateTokentroller(newTokentroller) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory reason) {
            emit CrossChainMessageFailed(currentMessageId, reason);
            revert(reason);
        }
    }

    function updateMetadataTokentroller(address newTokentroller) external override onlyFromRoot crossChainContext {
        require(newTokentroller != address(0), "New tokentroller address cannot be zero");
        require(newTokentroller != address(this), "New tokentroller address cannot be the same as the current address");

        try TokenMetadata(tokenMetadata).updateTokentroller(newTokentroller) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory reason) {
            emit CrossChainMessageFailed(currentMessageId, reason);
            revert(reason);
        }
    }

    function executeApproveToken(address token) external onlyFromRoot crossChainContext {
        try TokenRegistry(tokenRegistry).approveToken(token) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory reason) {
            emit CrossChainMessageFailed(currentMessageId, reason);
            revert(reason);
        }
    }

    function executeRejectToken(address token, string calldata reason) external onlyFromRoot crossChainContext {
        try TokenRegistry(tokenRegistry).rejectToken(token, reason) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory revertReason) {
            emit CrossChainMessageFailed(currentMessageId, revertReason);
            revert(revertReason);
        }
    }

    function executeAcceptTokenEdit(address token, uint256 editId) external onlyFromRoot crossChainContext {
        try TokenEdits(tokenEdits).acceptEdit(token, editId) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory reason) {
            emit CrossChainMessageFailed(currentMessageId, reason);
            revert(reason);
        }
    }

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

    function executeAddMetadataField(string calldata name) external onlyFromRoot crossChainContext {
        try TokenMetadata(tokenMetadata).addField(name) {
            emit CrossChainMessageExecuted(currentMessageId, msg.data);
        } catch Error(string memory reason) {
            emit CrossChainMessageFailed(currentMessageId, reason);
            revert(reason);
        }
    }

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
