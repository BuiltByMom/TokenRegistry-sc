// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokentrollerV1.sol";
import "@hyperlane/interfaces/IMailbox.sol";
import "@hyperlane/hooks/libs/StandardHookMetadata.sol";
import "../libraries/Commands.sol";

contract HyperlaneRootPlugin is TokentrollerV1 {
    using Commands for uint256;

    // Hyperlane mailbox contract
    IMailbox public immutable mailbox;

    // Mapping of child chain IDs to their Tokentroller addresses
    mapping(uint256 => address) public leafs;

    event MessageSent(bytes32 messageId, uint32 destinationDomain, bytes32 recipient, bytes message);
    event LeafSet(uint256 indexed chainId, address indexed leaf);

    // Tokentroller events
    event CrossChainTokenApproved(uint256 indexed chainId, address indexed token);
    event CrossChainTokenRejected(uint256 indexed chainId, address indexed token, string reason);
    event CrossChainTokenEditAccepted(uint256 indexed chainId, address indexed token, uint256 indexed editId);
    event CrossChainTokenEditRejected(uint256 indexed chainId, address indexed token, uint256 indexed editId);
    event CrossChainMetadataFieldAdded(uint256 indexed chainId, string indexed name);
    event CrossChainMetadataFieldUpdated(uint256 indexed chainId, string indexed name, bool isActive, bool isRequired);
    event CrossChainRegistryTokentrollerUpdated(uint256 indexed chainId, address indexed newTokentroller);
    event CrossChainMetadataTokentrollerUpdated(uint256 indexed chainId, address indexed newTokentroller);

    constructor(address _owner, address _mailbox) TokentrollerV1(_owner) {
        mailbox = IMailbox(_mailbox);
    }

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

    function quote(
        uint256 destinationDomain,
        bytes calldata messageBody,
        uint256 command
    ) external view returns (uint256) {
        return quote(destinationDomain, messageBody, command, 0);
    }

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

    function setLeaf(uint256 chainId, address leaf) external {
        require(msg.sender == owner, "Only owner can set leaf");
        require(leaf != address(0), "Invalid leaf address");
        leafs[chainId] = leaf;
        emit LeafSet(chainId, leaf);
    }

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

    function updateRegistryTokentroller(uint256 chainId, address newTokentroller) external payable {
        updateRegistryTokentroller(chainId, newTokentroller, 0);
    }

    function updateMetadataTokentroller(
        uint256 chainId,
        address newTokentroller,
        uint256 customGasLimit
    ) public payable {
        require(msg.sender == owner, "Only owner can update metadata tokentroller");
        require(newTokentroller != address(0), "New tokentroller address cannot be zero");

        bytes memory message = abi.encodeWithSignature("updateMetadataTokentroller(address)", newTokentroller);

        sendMessage(chainId, leafs[chainId], message, Commands.UPDATE_METADATA_TOKENTROLLER, customGasLimit);

        emit CrossChainMetadataTokentrollerUpdated(chainId, newTokentroller);
    }

    function updateMetadataTokentroller(uint256 chainId, address newTokentroller) external payable {
        updateMetadataTokentroller(chainId, newTokentroller, 0);
    }

    function approveTokenOnLeaf(uint256 chainId, address token, uint256 customGasLimit) public payable {
        require(msg.sender == owner, "Only owner can approve tokens");
        require(leafs[chainId] != address(0), "Leaf not set");

        bytes memory message = abi.encodeWithSignature("executeApproveToken(address)", token);

        sendMessage(chainId, leafs[chainId], message, Commands.APPROVE_TOKEN, customGasLimit);

        emit CrossChainTokenApproved(chainId, token);
    }

    function approveTokenOnLeaf(uint256 chainId, address token) external payable {
        approveTokenOnLeaf(chainId, token, 0);
    }

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

    function rejectTokenOnLeaf(uint256 chainId, address token, string calldata reason) external payable {
        rejectTokenOnLeaf(chainId, token, reason, 0);
    }

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

    function acceptTokenEditOnLeaf(uint256 chainId, address token, uint256 editId) external payable {
        acceptTokenEditOnLeaf(chainId, token, editId, 0);
    }

    function rejectTokenEditOnLeaf(
        uint256 chainId,
        address token,
        uint256 editId,
        uint256 customGasLimit
    ) public payable {
        require(msg.sender == owner, "Only owner can reject token edits");
        require(leafs[chainId] != address(0), "Leaf not set");

        bytes memory message = abi.encodeWithSignature("executeRejectTokenEdit(address,uint256)", token, editId);

        sendMessage(chainId, leafs[chainId], message, Commands.REJECT_TOKEN_EDIT, customGasLimit);

        emit CrossChainTokenEditRejected(chainId, token, editId);
    }

    function rejectTokenEditOnLeaf(uint256 chainId, address token, uint256 editId) external payable {
        rejectTokenEditOnLeaf(chainId, token, editId, 0);
    }

    function addMetadataFieldOnLeaf(uint256 chainId, string calldata name, uint256 customGasLimit) public payable {
        require(msg.sender == owner, "Only owner can add metadata fields");
        require(leafs[chainId] != address(0), "Leaf not set");

        bytes memory message = abi.encodeWithSignature("executeAddMetadataField(string)", name);

        sendMessage(chainId, leafs[chainId], message, Commands.ADD_METADATA_FIELD, customGasLimit);

        emit CrossChainMetadataFieldAdded(chainId, name);
    }

    function addMetadataFieldOnLeaf(uint256 chainId, string calldata name) external payable {
        addMetadataFieldOnLeaf(chainId, name, 0);
    }

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

    function updateMetadataFieldOnLeaf(
        uint256 chainId,
        string calldata name,
        bool isActive,
        bool isRequired
    ) external payable {
        updateMetadataFieldOnLeaf(chainId, name, isActive, isRequired, 0);
    }
}
