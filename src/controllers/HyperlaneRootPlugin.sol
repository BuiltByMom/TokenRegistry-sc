// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokentrollerV1.sol";
import "@hyperlane-xyz/core/interfaces/IMailbox.sol";

contract HyperlaneRootPlugin is TokentrollerV1 {
    // Hyperlane mailbox contract
    IMailbox public immutable mailbox;

    // Mapping of child chain IDs to their Tokentroller addresses
    mapping(uint256 => address) public leafs;

    event MessageSent(bytes32 messageId, uint32 destinationDomain, bytes32 recipient, bytes message);
    event LeafSet(uint256 indexed chainId, address indexed leaf);

    // Tokentroller events
    event CrossChainTokenApproved(uint256 indexed chainId, address indexed token);
    event CrossChainTokenRejected(uint256 indexed chainId, address indexed token, string reason);

    constructor(address _owner, address _mailbox) TokentrollerV1(_owner) {
        mailbox = IMailbox(_mailbox);
    }

    function sendMessage(uint256 destinationChainId, address target, bytes memory message) internal {
        bytes32 recipient = bytes32(uint256(uint160(target)));
        bytes32 messageId = mailbox.dispatch(uint32(destinationChainId), recipient, message);

        emit MessageSent(messageId, uint32(destinationChainId), recipient, message);
    }

    function setLeaf(uint256 chainId, address leaf) external {
        require(msg.sender == owner, "Only owner can set leaf");
        require(leaf != address(0), "Invalid leaf address");
        leafs[chainId] = leaf;
        emit LeafSet(chainId, leaf);
    }

    // Cross-chain token approval
    function approveTokenOnLeaf(uint256 chainId, address token) external {
        require(msg.sender == owner, "Only owner can approve tokens");
        require(leafs[chainId] != address(0), "Leaf not set");

        bytes memory message = abi.encodeWithSignature("executeApproveToken(address)", token);

        sendMessage(chainId, leafs[chainId], message);

        emit CrossChainTokenApproved(chainId, token);
    }

    // Cross-chain token rejection
    function rejectTokenOnLeaf(uint256 chainId, address token, string calldata reason) external {
        require(msg.sender == owner, "Only owner can reject tokens");
        require(leafs[chainId] != address(0), "Leaf not set");

        bytes memory message = abi.encodeWithSignature("executeRejectToken(address,string)", token, reason);

        sendMessage(chainId, leafs[chainId], message);

        emit CrossChainTokenRejected(chainId, token, reason);
    }
}
