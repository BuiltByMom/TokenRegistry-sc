// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ITokenRegistry.sol";
import "./interfaces/ITokenEdits.sol";
import "./interfaces/ISharedTypes.sol";
import "./interfaces/ITokenMetadata.sol";
import "./interfaces/ITokentroller.sol";

/**
 * @title Helper
 * @dev Helper contract for batch operations on TokenRegistry and TokenEdits
 */
contract Helper {
    ITokenRegistry public immutable tokenRegistry;
    ITokenEdits public immutable tokenEdits;
    ITokenMetadata public immutable tokenMetadata;
    ITokentroller public immutable tokentroller;

    struct BatchTokenInput {
        address contractAddress;
        MetadataInput[] metadata;
    }

    struct BatchEdits {
        address contractAddress;
        uint256 editId;
    }

    /**
     * @dev Constructor to initialize the helper with required contract addresses
     * @param _tokenRegistry Address of the TokenRegistry contract
     * @param _tokenEdits Address of the TokenEdits contract
     * @param _tokenMetadata Address of the TokenMetadata contract
     * @param _tokentroller Address of the Tokentroller contract
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
     * @dev Executes multiple token approvals
     * @param tokens Array of token addresses to approve
     */
    function batchApproveTokens(address[] calldata tokens) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokentroller.canApproveToken(msg.sender, tokens[i]), "Not authorized to approve token");
            tokenRegistry.approveToken(tokens[i]);
        }
    }

    /**
     * @dev Executes multiple token rejections
     * @param tokens Array of token addresses to reject
     * @param reason Reason for rejection
     */
    function batchRejectTokens(address[] calldata tokens, string calldata reason) public {
        require(bytes(reason).length > 0, "Empty reason");

        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokentroller.canRejectToken(msg.sender, tokens[i]), "Not authorized to reject token");
            tokenRegistry.rejectToken(tokens[i], reason);
        }
    }

    /**
     * @dev Executes multiple token additions and approvals
     * @param tokens Array of BatchTokenInput structs
     */
    function batchAddAndApproveTokens(BatchTokenInput[] calldata tokens) external {
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokentroller.canAddToken(msg.sender, tokens[i].contractAddress), "Not authorized to add token");
            tokenRegistry.addToken(tokens[i].contractAddress, tokens[i].metadata);

            require(
                tokentroller.canApproveToken(msg.sender, tokens[i].contractAddress),
                "Not authorized to approve token"
            );
            tokenRegistry.approveToken(tokens[i].contractAddress);
        }
    }

    /**
     * @dev Executes multiple edit rejections
     * @param edits Array of BatchEdits structs
     * @param reason Reason for rejection
     */
    function batchRejectEdits(BatchEdits[] calldata edits, string calldata reason) public {
        require(bytes(reason).length > 0, "Empty reason");

        for (uint256 i = 0; i < edits.length; i++) {
            require(
                tokentroller.canRejectTokenEdit(msg.sender, edits[i].contractAddress, edits[i].editId),
                "Not authorized to reject edit"
            );
            tokenEdits.rejectEdit(edits[i].contractAddress, edits[i].editId, reason);
        }
    }

    /**
     * @dev Executes multiple edit acceptances
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
     * @dev Executes multiple token approvals and edit acceptances
     * @param tokens Array of token addresses
     * @param edits Array of BatchEdits structs
     */
    function batchApproveAndAcceptEdits(address[] calldata tokens, BatchEdits[] calldata edits) external {
        batchApproveTokens(tokens);
        batchAcceptEdits(edits);
    }

    /**
     * @dev Executes multiple token rejections and edit rejections
     * @param tokens Array of token addresses
     * @param edits Array of BatchEdits structs
     * @param reason Reason for rejection
     */
    function batchRejectAndRejectEdits(
        address[] calldata tokens,
        BatchEdits[] calldata edits,
        string calldata reason
    ) external {
        batchRejectTokens(tokens, reason);
        batchRejectEdits(edits, reason);
    }
}
