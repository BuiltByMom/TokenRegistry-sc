// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

    // Result struct to track success/failure of each operation
    struct BatchResult {
        address token;
        bool success;
        string errorMessage;
        uint256 editId; // Only used for edit operations
    }

    struct BatchEdits {
        address contractAddress;
        uint256 editId;
    }

    struct BatchTokenInput {
        address contractAddress;
        MetadataInput[] metadata;
    }

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
     * @dev Executes multiple token approvals using multicall pattern
     * @param tokens Array of token addresses to approve
     * @return results Array of results for each operation
     * @return summary Tuple of (total, succeeded, failed)
     */
    function batchApproveTokens(
        address[] calldata tokens
    ) public returns (BatchResult[] memory results, uint256[3] memory summary) {
        results = new BatchResult[](tokens.length);
        summary[0] = tokens.length; // total

        for (uint256 i = 0; i < tokens.length; i++) {
            results[i].token = tokens[i];

            if (tokens[i] == address(0)) {
                results[i].success = false;
                results[i].errorMessage = "Invalid token address";
                summary[2]++; // failed
                continue;
            }

            if (!tokentroller.canApproveToken(msg.sender, tokens[i])) {
                results[i].success = false;
                results[i].errorMessage = "Not authorized to approve token";
                summary[2]++; // failed
                continue;
            }

            try tokenRegistry.approveToken(tokens[i]) {
                results[i].success = true;
                summary[1]++; // succeeded
            } catch Error(string memory reason) {
                results[i].success = false;
                results[i].errorMessage = reason;
                summary[2]++; // failed
            } catch (bytes memory) {
                results[i].success = false;
                results[i].errorMessage = "Unknown error";
                summary[2]++; // failed
            }
        }
    }

    /**
     * @dev Executes multiple token rejections using multicall pattern
     * @param tokens Array of token addresses to reject
     * @param reason Reason for rejection
     * @return results Array of results for each operation
     * @return summary Tuple of (total, succeeded, failed)
     */
    function batchRejectTokens(
        address[] calldata tokens,
        string calldata reason
    ) public returns (BatchResult[] memory results, uint256[3] memory summary) {
        require(bytes(reason).length > 0, "Empty reason");
        results = new BatchResult[](tokens.length);
        summary[0] = tokens.length; // total

        for (uint256 i = 0; i < tokens.length; i++) {
            results[i].token = tokens[i];

            if (tokens[i] == address(0)) {
                results[i].success = false;
                results[i].errorMessage = "Invalid token address";
                summary[2]++; // failed
                continue;
            }

            if (!tokentroller.canRejectToken(msg.sender, tokens[i])) {
                results[i].success = false;
                results[i].errorMessage = "Not authorized to reject token";
                summary[2]++; // failed
                continue;
            }

            try tokenRegistry.rejectToken(tokens[i], reason) {
                results[i].success = true;
                summary[1]++; // succeeded
            } catch Error(string memory revertReason) {
                results[i].success = false;
                results[i].errorMessage = revertReason;
                summary[2]++; // failed
            } catch (bytes memory) {
                results[i].success = false;
                results[i].errorMessage = "Unknown error";
                summary[2]++; // failed
            }
        }
    }

    /**
     * @dev Executes multiple token additions and approvals using multicall pattern
     * @param tokens Array of BatchTokenInput structs
     * @return results Array of results for each operation
     * @return summary Tuple of (total, succeeded, failed)
     */
    function batchAddAndApproveTokens(
        BatchTokenInput[] calldata tokens
    ) external returns (BatchResult[] memory results, uint256[3] memory summary) {
        results = new BatchResult[](tokens.length);
        summary[0] = tokens.length; // total

        for (uint256 i = 0; i < tokens.length; i++) {
            results[i].token = tokens[i].contractAddress;

            if (tokens[i].contractAddress == address(0)) {
                results[i].success = false;
                results[i].errorMessage = "Invalid token address";
                summary[2]++; // failed
                continue;
            }

            if (!tokentroller.canAddToken(msg.sender, tokens[i].contractAddress)) {
                results[i].success = false;
                results[i].errorMessage = "Not authorized to add token";
                summary[2]++; // failed
                continue;
            }

            if (!tokentroller.canApproveToken(msg.sender, tokens[i].contractAddress)) {
                results[i].success = false;
                results[i].errorMessage = "Not authorized to approve token";
                summary[2]++; // failed
                continue;
            }

            try tokenRegistry.addToken(tokens[i].contractAddress, tokens[i].metadata) {
                try tokenRegistry.approveToken(tokens[i].contractAddress) {
                    results[i].success = true;
                    summary[1]++; // succeeded
                } catch Error(string memory reason) {
                    results[i].success = false;
                    results[i].errorMessage = reason;
                    summary[2]++; // failed
                } catch (bytes memory) {
                    results[i].success = false;
                    results[i].errorMessage = "Unknown error during approval";
                    summary[2]++; // failed
                }
            } catch Error(string memory reason) {
                results[i].success = false;
                results[i].errorMessage = reason;
                summary[2]++; // failed
            } catch (bytes memory) {
                results[i].success = false;
                results[i].errorMessage = "Unknown error during addition";
                summary[2]++; // failed
            }
        }
    }

    /**
     * @dev Executes multiple edit acceptances using multicall pattern
     * @param edits Array of BatchEdits structs
     * @return results Array of results for each operation
     * @return summary Tuple of (total, succeeded, failed)
     */
    function batchAcceptEdits(
        BatchEdits[] calldata edits
    ) public returns (BatchResult[] memory results, uint256[3] memory summary) {
        results = new BatchResult[](edits.length);
        summary[0] = edits.length; // total

        for (uint256 i = 0; i < edits.length; i++) {
            results[i].token = edits[i].contractAddress;
            results[i].editId = edits[i].editId;

            if (edits[i].contractAddress == address(0)) {
                results[i].success = false;
                results[i].errorMessage = "Invalid token address";
                summary[2]++; // failed
                continue;
            }
            if (edits[i].editId == 0) {
                results[i].success = false;
                results[i].errorMessage = "Invalid edit ID";
                summary[2]++; // failed
                continue;
            }

            if (!tokentroller.canAcceptTokenEdit(msg.sender, edits[i].contractAddress, edits[i].editId)) {
                results[i].success = false;
                results[i].errorMessage = "Not authorized to accept edit";
                summary[2]++; // failed
                continue;
            }

            try tokenEdits.acceptEdit(edits[i].contractAddress, edits[i].editId) {
                results[i].success = true;
                summary[1]++; // succeeded
            } catch Error(string memory reason) {
                results[i].success = false;
                results[i].errorMessage = reason;
                summary[2]++; // failed
            } catch (bytes memory) {
                results[i].success = false;
                results[i].errorMessage = "Unknown error";
                summary[2]++; // failed
            }
        }
    }

    /**
     * @dev Executes multiple edit rejections using multicall pattern
     * @param edits Array of BatchEdits structs
     * @param reason Reason for rejection
     * @return results Array of results for each operation
     * @return summary Tuple of (total, succeeded, failed)
     */
    function batchRejectEdits(
        BatchEdits[] calldata edits,
        string calldata reason
    ) public returns (BatchResult[] memory results, uint256[3] memory summary) {
        require(bytes(reason).length > 0, "Empty reason");
        results = new BatchResult[](edits.length);
        summary[0] = edits.length; // total

        for (uint256 i = 0; i < edits.length; i++) {
            results[i].token = edits[i].contractAddress;
            results[i].editId = edits[i].editId;

            if (edits[i].contractAddress == address(0)) {
                results[i].success = false;
                results[i].errorMessage = "Invalid token address";
                summary[2]++; // failed
                continue;
            }
            if (edits[i].editId == 0) {
                results[i].success = false;
                results[i].errorMessage = "Invalid edit ID";
                summary[2]++; // failed
                continue;
            }

            if (!tokentroller.canRejectTokenEdit(msg.sender, edits[i].contractAddress, edits[i].editId)) {
                results[i].success = false;
                results[i].errorMessage = "Not authorized to reject edit";
                summary[2]++; // failed
                continue;
            }

            try tokenEdits.rejectEdit(edits[i].contractAddress, edits[i].editId, reason) {
                results[i].success = true;
                summary[1]++; // succeeded
            } catch Error(string memory revertReason) {
                results[i].success = false;
                results[i].errorMessage = revertReason;
                summary[2]++; // failed
            } catch (bytes memory) {
                results[i].success = false;
                results[i].errorMessage = "Unknown error";
                summary[2]++; // failed
            }
        }
    }

    /**
     * @dev Executes multiple token approvals and edit acceptances using multicall pattern
     * @param tokens Array of token addresses
     * @param edits Array of BatchEdits structs
     * @return tokenResults Results of token operations
     * @return editResults Results of edit operations
     * @return tokenSummary Summary of token operations (total, succeeded, failed)
     * @return editSummary Summary of edit operations (total, succeeded, failed)
     */
    function batchApproveAndAcceptEdits(
        address[] calldata tokens,
        BatchEdits[] calldata edits
    )
        external
        returns (
            BatchResult[] memory tokenResults,
            BatchResult[] memory editResults,
            uint256[3] memory tokenSummary,
            uint256[3] memory editSummary
        )
    {
        (tokenResults, tokenSummary) = batchApproveTokens(tokens);
        (editResults, editSummary) = batchAcceptEdits(edits);
    }

    /**
     * @dev Executes multiple token rejections and edit rejections using multicall pattern
     * @param tokens Array of token addresses
     * @param edits Array of BatchEdits structs
     * @param reason Reason for rejection
     * @return tokenResults Results of token operations
     * @return editResults Results of edit operations
     * @return tokenSummary Summary of token operations (total, succeeded, failed)
     * @return editSummary Summary of edit operations (total, succeeded, failed)
     */
    function batchRejectAndRejectEdits(
        address[] calldata tokens,
        BatchEdits[] calldata edits,
        string calldata reason
    )
        external
        returns (
            BatchResult[] memory tokenResults,
            BatchResult[] memory editResults,
            uint256[3] memory tokenSummary,
            uint256[3] memory editSummary
        )
    {
        (tokenResults, tokenSummary) = batchRejectTokens(tokens, reason);
        (editResults, editSummary) = batchRejectEdits(edits, reason);
    }
}
