// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ITokenRegistry.sol";
import "./interfaces/ITokentroller.sol";
import "./interfaces/ITokenMetadata.sol";
import "./interfaces/ISharedTypes.sol";

/**********************************************************************************************
 * @title TokenRegistry
 * @dev A contract that manages the registration and approval of tokens.
 * This contract maintains a list of approved tokens and their status,
 * with governance controls for approving and rejecting token registrations.
 *********************************************************************************************/
contract TokenRegistry is ITokenRegistry, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(TokenStatus => EnumerableSet.AddressSet) private tokensByStatus;

    ITokenMetadata public immutable tokenMetadata;

    address public tokentroller;

    /**********************************************************************************************
     * @dev Constructor for the TokenRegistry contract
     * @param _tokentroller The address of the tokentroller contract
     * @param _tokenMetadata The address of the token metadata contract
     * @notice Initializes the contract with the tokentroller and metadata contract addresses
     *********************************************************************************************/
    constructor(address _tokentroller, address _tokenMetadata) {
        require(_tokentroller != address(0), "TokenRegistry: tokentroller cannot be zero address");
        require(_tokenMetadata != address(0), "TokenRegistry: tokenMetadata cannot be zero address");
        tokentroller = _tokentroller;
        tokenMetadata = ITokenMetadata(_tokenMetadata);
    }

    /**********************************************************************************************
     *  __  __       _        _
     * |  \/  |_   _| |_ __ _| |_ ___  _ __ ___
     * | |\/| | | | | __/ _` | __/ _ \| '__/ __|
     * | |  | | |_| | || (_| | || (_) | |  \__ \
     * |_|  |_|\__,_|\__\__,_|\__\___/|_|  |___/
     *
     * @dev These functions are designed to alter the state of the registry.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Registers a new token with metadata
     * @param contractAddress The address of the token contract to register
     * @param metadata Array of metadata fields and values for the token
     * @notice This function can only be called by authorized addresses
     * @notice The token must be a valid ERC20 token and not already registered
     * @notice Emits a TokenAdded event on success
     *********************************************************************************************/
    function addToken(address contractAddress, MetadataInput[] calldata metadata) external nonReentrant {
        require(ITokentroller(tokentroller).canAddToken(msg.sender, contractAddress), "Not authorized to add token");

        // Verify it's a valid ERC20 token
        IERC20Metadata token = IERC20Metadata(contractAddress);
        token.name(); // Will revert if not implemented
        token.symbol();
        token.decimals();

        require(
            !tokensByStatus[TokenStatus.PENDING].contains(contractAddress) &&
                !tokensByStatus[TokenStatus.APPROVED].contains(contractAddress),
            "Token already exists in pending or approved state"
        );

        // Remove from rejected if exists
        if (tokensByStatus[TokenStatus.REJECTED].contains(contractAddress)) {
            bool removed = tokensByStatus[TokenStatus.REJECTED].remove(contractAddress);
            require(removed, "Failed to remove from rejected status");
        }

        bool added = tokensByStatus[TokenStatus.PENDING].add(contractAddress);
        require(added, "Failed to add to pending status");

        tokenMetadata.updateMetadata(contractAddress, metadata);

        emit TokenAdded(contractAddress, msg.sender);
    }

    /**********************************************************************************************
     * @dev Approves a pending token registration
     * @param contractAddress The address of the token contract to approve
     * @notice This function can only be called by authorized addresses
     * @notice The token must be in pending status
     * @notice Emits a TokenApproved event on success
     *********************************************************************************************/
    function approveToken(address contractAddress) external nonReentrant {
        require(
            ITokentroller(tokentroller).canApproveToken(msg.sender, contractAddress),
            "Not authorized to approve token"
        );
        require(tokensByStatus[TokenStatus.PENDING].contains(contractAddress), "Token not found in pending state");

        bool removed = tokensByStatus[TokenStatus.PENDING].remove(contractAddress);
        require(removed, "Failed to remove from pending status");

        bool added = tokensByStatus[TokenStatus.APPROVED].add(contractAddress);
        require(added, "Failed to add to approved status");

        emit TokenApproved(contractAddress);
    }

    /**********************************************************************************************
     * @dev Rejects a token registration
     * @param contractAddress The address of the token contract to reject
     * @param reason The reason for rejecting the token
     * @notice This function can only be called by authorized addresses
     * @notice The token must not already be rejected
     * @notice Emits a TokenRejected event on success
     *********************************************************************************************/
    function rejectToken(address contractAddress, string calldata reason) external nonReentrant {
        require(
            ITokentroller(tokentroller).canRejectToken(msg.sender, contractAddress),
            "Not authorized to reject token"
        );
        require(tokenStatus(contractAddress) != TokenStatus.REJECTED, "Token already rejected");

        bool removed = tokensByStatus[tokenStatus(contractAddress)].remove(contractAddress);
        require(removed, "Failed to remove from current status");

        bool added = tokensByStatus[TokenStatus.REJECTED].add(contractAddress);
        require(added, "Failed to add to rejected status");

        emit TokenRejected(contractAddress, reason);
    }

    /**********************************************************************************************
     *     _
     *    / \   ___ ___ ___  ___ ___  ___  _ __ ___
     *   / _ \ / __/ __/ _ \/ __/ __|/ _ \| '__/ __|
     *  / ___ \ (_| (_|  __/\__ \__ \ (_) | |  \__ \
     * /_/   \_\___\___\___||___/___/\___/|_|  |___/
     *
     * @dev These functions are for the public to get information about the registry.
     * They do not require any special permissions or access control and are read-only.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Internal function to get token information
     * @param contractAddress The address of the token contract
     * @param includeMetadata Whether to include full metadata in the response
     * @return Token A struct containing token information and metadata
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function _getToken(address contractAddress, bool includeMetadata) internal view returns (Token memory) {
        Token memory token = Token({
            contractAddress: contractAddress,
            name: IERC20Metadata(contractAddress).name(),
            symbol: IERC20Metadata(contractAddress).symbol(),
            decimals: IERC20Metadata(contractAddress).decimals(),
            logoURI: tokenMetadata.getMetadata(contractAddress, "logoURI"),
            status: tokenStatus(contractAddress),
            metadata: includeMetadata ? tokenMetadata.getAllMetadata(contractAddress) : new MetadataValue[](0)
        });
        return token;
    }

    /**********************************************************************************************
     * @dev Internal function to get information for multiple tokens
     * @param contractAddresses Array of token contract addresses
     * @param includeMetadata Whether to include full metadata in the response
     * @return Token[] Array of token information structs
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function _getTokens(
        address[] calldata contractAddresses,
        bool includeMetadata
    ) internal view returns (Token[] memory) {
        Token[] memory tokens = new Token[](contractAddresses.length);
        for (uint256 i = 0; i < contractAddresses.length; i++) {
            tokens[i] = _getToken(contractAddresses[i], includeMetadata);
        }
        return tokens;
    }

    /**********************************************************************************************
     * @dev Gets information for a single token
     * @param contractAddress The address of the token contract
     * @return Token A struct containing token information without metadata
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function getToken(address contractAddress) external view returns (Token memory) {
        return _getToken(contractAddress, false);
    }

    /**********************************************************************************************
     * @dev Gets information for a single token with optional metadata
     * @param contractAddress The address of the token contract
     * @param includeMetadata Whether to include full metadata in the response
     * @return Token A struct containing token information and optional metadata
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function getToken(address contractAddress, bool includeMetadata) external view returns (Token memory) {
        return _getToken(contractAddress, includeMetadata);
    }

    /**********************************************************************************************
     * @dev Gets information for multiple tokens
     * @param contractAddresses Array of token contract addresses
     * @return Token[] Array of token information structs without metadata
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function getTokens(address[] calldata contractAddresses) external view returns (Token[] memory) {
        return _getTokens(contractAddresses, false);
    }

    /**********************************************************************************************
     * @dev Gets information for multiple tokens with optional metadata
     * @param contractAddresses Array of token contract addresses
     * @param includeMetadata Whether to include full metadata in the response
     * @return Token[] Array of token information structs with optional metadata
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function getTokens(
        address[] calldata contractAddresses,
        bool includeMetadata
    ) external view returns (Token[] memory) {
        return _getTokens(contractAddresses, includeMetadata);
    }

    /**********************************************************************************************
     * @dev Internal function to list tokens with pagination
     * @param offset The starting index for pagination
     * @param limit The maximum number of tokens to return
     * @param status The status of tokens to list
     * @param includeMetadata Whether to include full metadata in the response
     * @return tokens Array of token information structs
     * @return total Total number of tokens with the specified status
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function _listTokens(
        uint256 offset,
        uint256 limit,
        TokenStatus status,
        bool includeMetadata
    ) internal view returns (Token[] memory tokens, uint256 total) {
        EnumerableSet.AddressSet storage statusSet = tokensByStatus[status];
        total = statusSet.length();

        if (offset >= total) {
            return (new Token[](0), total);
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        uint256 resultLength = end - offset;
        tokens = new Token[](resultLength);

        for (uint256 i = 0; i < resultLength; i++) {
            address tokenAddress = statusSet.at(offset + i);
            tokens[i] = _getToken(tokenAddress, includeMetadata);
        }
    }

    /**********************************************************************************************
     * @dev Lists tokens with pagination
     * @param offset The starting index for pagination
     * @param limit The maximum number of tokens to return
     * @param status The status of tokens to list
     * @return tokens Array of token information structs without metadata
     * @return total Total number of tokens with the specified status
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function listTokens(
        uint256 offset,
        uint256 limit,
        TokenStatus status
    ) external view returns (Token[] memory tokens, uint256 total) {
        return _listTokens(offset, limit, status, false);
    }

    /**********************************************************************************************
     * @dev Lists tokens with pagination and optional metadata
     * @param offset The starting index for pagination
     * @param limit The maximum number of tokens to return
     * @param status The status of tokens to list
     * @param includeMetadata Whether to include full metadata in the response
     * @return tokens Array of token information structs with optional metadata
     * @return total Total number of tokens with the specified status
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function listTokens(
        uint256 offset,
        uint256 limit,
        TokenStatus status,
        bool includeMetadata
    ) external view returns (Token[] memory tokens, uint256 total) {
        return _listTokens(offset, limit, status, includeMetadata);
    }

    /**********************************************************************************************
     * @dev Gets the current status of a token
     * @param contractAddress The address of the token contract
     * @return TokenStatus The current status of the token
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function tokenStatus(address contractAddress) public view returns (TokenStatus) {
        if (tokensByStatus[TokenStatus.APPROVED].contains(contractAddress)) {
            return TokenStatus.APPROVED;
        } else if (tokensByStatus[TokenStatus.PENDING].contains(contractAddress)) {
            return TokenStatus.PENDING;
        } else if (tokensByStatus[TokenStatus.REJECTED].contains(contractAddress)) {
            return TokenStatus.REJECTED;
        } else {
            return TokenStatus.NONE;
        }
    }

    /**********************************************************************************************
     * @dev Gets the count of tokens in each status
     * @return pending Number of tokens in pending status
     * @return approved Number of tokens in approved status
     * @return rejected Number of tokens in rejected status
     * @notice This is a view function and does not modify state
     *********************************************************************************************/
    function getTokenCounts() external view returns (uint256 pending, uint256 approved, uint256 rejected) {
        pending = tokensByStatus[TokenStatus.PENDING].length();
        approved = tokensByStatus[TokenStatus.APPROVED].length();
        rejected = tokensByStatus[TokenStatus.REJECTED].length();
    }

    /**********************************************************************************************
     *  _____     _              _             _ _
     * |_   _|__ | | _____ _ __ | |_ _ __ ___ | | | ___ _ __
     *   | |/ _ \| |/ / _ \ '_ \| __| '__/ _ \| | |/ _ \ '__|
     *   | | (_) |   <  __/ | | | |_| | | (_) | | |  __/ |
     *   |_|\___/|_|\_\___|_| |_|\__|_|  \___/|_|_|\___|_|
     *
     * @dev All the functions below are to manage the registry with tokentroller.
     * All the verifications are handled by the Tokentroller contract, which can be upgraded at
     * any time by the owner of the contract.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Updates the tokentroller address
     * @param newTokentroller The address of the new tokentroller
     * @notice This function can only be called by the current tokentroller
     * @notice Emits a TokentrollerUpdated event on success
     *********************************************************************************************/
    function updateTokentroller(address newTokentroller) external {
        require(msg.sender == tokentroller, "Not authorized");
        require(newTokentroller != address(0), "TokenRegistry: tokentroller cannot be zero address");
        tokentroller = newTokentroller;
        emit TokentrollerUpdated(newTokentroller);
    }
}
