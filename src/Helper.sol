// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokenRegistry.sol";
import "./interfaces/ITokenEdits.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenMetadata.sol";
import "./interfaces/ITokentroller.sol";

/**
 * @title Helper
 * @dev A helper contract that provides convenient functions for managing tokens and their edits
 * in the TokenRegistry system. This contract combines multiple operations into single transactions
 * for better efficiency and ease of use.
 */
contract Helper {
    ITokenRegistry public immutable tokenRegistry;
    ITokenEdits public immutable tokenEdits;
    ITokenMetadata public immutable tokenMetadata;
    ITokentroller public immutable tokentroller;

    /**
     * @dev Constructor to initialize the helper with required contract addresses
     * @param _tokenRegistry Address of the TokenRegistry contract
     * @param _tokenEdits Address of the TokenEdits contract
     * @param _tokenMetadata Address of the TokenMetadata contract
     */
    constructor(address _tokenRegistry, address _tokenEdits, address _tokenMetadata, address _tokentroller) {
        require(_tokenRegistry != address(0), "Invalid token registry address");
        require(_tokenEdits != address(0), "Invalid token edits address");
        require(_tokenMetadata != address(0), "Invalid token metadata address");
        require(_tokentroller != address(0), "Invalid tokentroller address");
        tokenRegistry = ITokenRegistry(_tokenRegistry);
        tokenEdits = ITokenEdits(_tokenEdits);
        tokenMetadata = ITokenMetadata(_tokenMetadata);
        tokentroller = ITokentroller(_tokentroller);
    }

    /**
     * @dev Add and immediately approve a token
     * @param contractAddress Token contract address
     * @param metadata Array of metadata fields and values
     */
    function addAndApproveToken(address contractAddress, MetadataInput[] calldata metadata) external {
        require(tokentroller.canAddToken(msg.sender, contractAddress), "Not authorized to add token");
        require(tokentroller.canApproveToken(msg.sender, contractAddress), "Not authorized to approve token");
        tokenRegistry.addToken(contractAddress, metadata);
        tokenRegistry.approveToken(contractAddress);
    }

    /**
     * @dev Propose and immediately approve an edit
     * @param contractAddress Token contract address
     * @param metadata Array of metadata fields and values
     */
    function proposeAndApproveEdit(address contractAddress, MetadataInput[] calldata metadata) external {
        require(tokentroller.canProposeTokenEdit(msg.sender, contractAddress), "Not authorized to propose edit");

        uint256 editId = tokenEdits.proposeEdit(contractAddress, metadata);

        require(tokentroller.canAcceptTokenEdit(msg.sender, contractAddress, editId), "Not authorized to accept edit");
        tokenEdits.acceptEdit(contractAddress, editId);
    }

    /**
     * @dev Batch approve multiple tokens
     * @param tokens Array of token addresses to approve
     */
    function batchApproveTokens(address[] calldata tokens) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokentroller.canApproveToken(msg.sender, tokens[i]), "Not authorized to approve token");
            tokenRegistry.approveToken(tokens[i]);
        }
    }

    /**
     * @dev Batch reject multiple tokens
     * @param tokens Array of token addresses to reject
     * @param reason Reason for rejection
     */
    function batchRejectTokens(address[] calldata tokens, string calldata reason) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokentroller.canRejectToken(msg.sender, tokens[i]), "Not authorized to reject token");
            tokenRegistry.rejectToken(tokens[i], reason);
        }
    }

    struct BatchEdits {
        address contractAddress;
        uint256 editId;
    }

    /**
     * @dev Batch accept multiple edits for multiple tokens
     * @param edits Array of BatchEdits structs
     */
    function batchAcceptEdits(BatchEdits[] calldata edits) public {
        for (uint256 i = 0; i < edits.length; i++) {
            require(
                tokentroller.canAcceptTokenEdit(msg.sender, edits[i].contractAddress, edits[i].editId),
                "Not authorized to accept edit"
            );
            tokenEdits.acceptEdit(edits[i].contractAddress, edits[i].editId);
        }
    }

    /**
     * @dev Batch reject multiple edits for multiple tokens
     * @param edits Array of BatchEdits structs
     */
    function batchRejectEdits(BatchEdits[] calldata edits, string calldata reason) public {
        for (uint256 i = 0; i < edits.length; i++) {
            require(
                tokentroller.canRejectTokenEdit(msg.sender, edits[i].contractAddress, edits[i].editId),
                "Not authorized to reject edit"
            );
            tokenEdits.rejectEdit(edits[i].contractAddress, edits[i].editId, reason);
        }
    }

    /**
     * @dev Batch approve and accept edits for multiple tokens
     * @param tokens Array of token addresses
     * @param edits Array of BatchEdits structs
     */
    function batchApproveAndAcceptEdits(address[] calldata tokens, BatchEdits[] calldata edits) external {
        batchAcceptEdits(edits);
        batchApproveTokens(tokens);
    }

    /**
     * @dev Batch reject and reject edits for multiple tokens
     * @param tokens Array of token addresses
     * @param edits Array of BatchEdits structs
     */
    function batchRejectAndRejectEdits(
        address[] calldata tokens,
        BatchEdits[] calldata edits,
        string calldata reason
    ) external {
        batchRejectEdits(edits, reason);
        batchRejectTokens(tokens, reason);
    }
}
