// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../TokentrollerV1.sol";
import "@hyperlane-xyz/core/interfaces/IMailbox.sol";

contract TokentrollerRoot is TokentrollerV1 {
    // Hyperlane mailbox contract
    IMailbox public immutable mailbox;

    // Mapping of child chain IDs to their Tokentroller addresses
    mapping(uint256 => address) public tokentrollersLeafs;

    event MessageSent(bytes32 messageId, uint32 destinationDomain, bytes32 recipient, bytes message);
    event TokentrollerLeafSet(uint256 indexed chainId, address indexed tokentroller);
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

    function setTokentrollerLeaf(uint256 chainId, address tokentrollerLeaf) external {
        require(msg.sender == owner, "Only owner can set leaf tokentroller");
        require(tokentrollerLeaf != address(0), "Invalid leaf tokentroller address");
        tokentrollersLeafs[chainId] = tokentrollerLeaf;
        emit TokentrollerLeafSet(chainId, tokentrollerLeaf);
    }

    // Cross-chain token approval
    function approveTokenOnLeaf(uint256 chainId, address token) external {
        require(msg.sender == owner, "Only owner can approve tokens");
        require(tokentrollersLeafs[chainId] != address(0), "Leaf tokentroller not set");

        bytes memory message = abi.encodeWithSignature("executeApproveToken(address)", token);

        sendMessage(chainId, tokentrollersLeafs[chainId], message);

        emit CrossChainTokenApproved(chainId, token);
    }

    // Cross-chain token rejection
    function rejectTokenOnLeaf(uint256 chainId, address token, string calldata reason) external {
        require(msg.sender == owner, "Only owner can reject tokens");
        require(tokentrollersLeafs[chainId] != address(0), "Leaf tokentroller not set");

        bytes memory message = abi.encodeWithSignature("executeRejectToken(address,string)", token, reason);

        sendMessage(chainId, tokentrollersLeafs[chainId], message);

        emit CrossChainTokenRejected(chainId, token, reason);
    }
}
