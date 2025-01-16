// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokentroller.sol";
import "./interfaces/ITokenRegistry.sol";
import "./interfaces/ITokenMetadataRegistry.sol";

contract TokenRegistry is ITokenRegistry {
    // Main token storage - status => token address => token info
    mapping(TokenStatus => mapping(address => Token)) public tokens;

    // Token addresses list
    address[] public tokenAddresses;

    // Token counts per status
    uint256 public pendingTokenCount;
    uint256 public approvedTokenCount;
    uint256 public rejectedTokenCount;

    // Governance
    address public tokentroller;
    address public metadataRegistry;

    constructor(address _tokentroller, address _metadataRegistry) {
        tokentroller = _tokentroller;
        metadataRegistry = _metadataRegistry;
    }

    function addToken(
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals
    ) public {
        require(
            tokens[TokenStatus.PENDING][contractAddress].contractAddress == address(0) &&
                tokens[TokenStatus.APPROVED][contractAddress].contractAddress == address(0),
            "Token already exists in pending or approved state"
        );
        require(contractAddress != address(0), "New token address cannot be zero");
        require(ITokentroller(tokentroller).canAddToken(msg.sender, contractAddress), "Failed to add token");

        Token memory newToken = Token({
            contractAddress: contractAddress,
            submitter: msg.sender,
            name: name,
            logoURI: logoURI,
            symbol: symbol,
            decimals: decimals
        });

        // If token was previously rejected, update it instead of adding new entry
        if (tokens[TokenStatus.REJECTED][contractAddress].contractAddress != address(0)) {
            delete tokens[TokenStatus.REJECTED][contractAddress];
            rejectedTokenCount--;
        } else {
            tokenAddresses.push(contractAddress);
        }

        tokens[TokenStatus.PENDING][contractAddress] = newToken;
        pendingTokenCount++;

        emit TokenAdded(contractAddress, name, symbol, logoURI, decimals);
    }

    function approveToken(address contractAddress) public {
        require(
            tokens[TokenStatus.PENDING][contractAddress].contractAddress != address(0),
            "Token must be in pending state"
        );
        require(ITokentroller(tokentroller).canApproveToken(msg.sender, contractAddress), "Failed to approve token");

        Token memory token = tokens[TokenStatus.PENDING][contractAddress];
        delete tokens[TokenStatus.PENDING][contractAddress];
        tokens[TokenStatus.APPROVED][contractAddress] = token;

        pendingTokenCount--;
        approvedTokenCount++;

        emit TokenApproved(contractAddress);
    }

    function rejectToken(address contractAddress, string calldata reason) public {
        require(
            tokens[TokenStatus.PENDING][contractAddress].contractAddress != address(0),
            "Token must be in pending state"
        );
        require(ITokentroller(tokentroller).canRejectToken(msg.sender, contractAddress), "Failed to reject token");

        Token memory token = tokens[TokenStatus.PENDING][contractAddress];
        delete tokens[TokenStatus.PENDING][contractAddress];
        tokens[TokenStatus.REJECTED][contractAddress] = token;

        pendingTokenCount--;
        rejectedTokenCount++;

        emit TokenRejected(contractAddress, reason);
    }

    function listTokens(
        uint256 offset,
        uint256 limit,
        TokenStatus status
    ) external view returns (Token[] memory tokens_, uint256 total) {
        require(limit > 0, "Limit must be greater than zero");

        // Get the total count for the requested status
        total = (status == TokenStatus.PENDING)
            ? pendingTokenCount
            : (status == TokenStatus.APPROVED)
                ? approvedTokenCount
                : rejectedTokenCount;

        // Early return if no tokens or invalid initial index
        if (total == 0 || offset >= total) {
            return (new Token[](0), total);
        }

        // Calculate optimal array size
        uint256 size = (offset + limit > total) ? total - offset : limit;
        tokens_ = new Token[](size);

        uint256 found; // Number of tokens found for the requested status
        uint256 statusCount; // Running count of tokens matching the status

        for (uint256 i = 0; i < tokenAddresses.length && found < size; i++) {
            (Token memory token, bool exists) = _getTokenAtIndex(i, status);

            if (exists) {
                if (statusCount >= offset) {
                    tokens_[found] = token;
                    found++;
                }
                statusCount++;
            }
        }

        return (tokens_, total);
    }

    function getTokenCounts() external view returns (uint256 pending, uint256 approved, uint256 rejected) {
        return (pendingTokenCount, approvedTokenCount, rejectedTokenCount);
    }

    function tokenCount() external view returns (uint256) {
        return tokenAddresses.length;
    }

    function _getTokenAtIndex(
        uint256 index,
        TokenStatus status
    ) private view returns (Token memory token, bool exists) {
        address tokenAddress = tokenAddresses[index];
        token = tokens[status][tokenAddress];
        exists = token.contractAddress != address(0);
    }

    function updateTokentroller(address newTokentroller) public {
        require(msg.sender == tokentroller, "Only tokentroller can update");
        tokentroller = newTokentroller;
        emit TokentrollerUpdated(newTokentroller);
    }

    function updateToken(
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals
    ) external {
        require(ITokentroller(tokentroller).canUpdateToken(msg.sender, contractAddress), "Not authorized");
        require(tokens[TokenStatus.APPROVED][contractAddress].contractAddress != address(0), "Token must be approved");

        tokens[TokenStatus.APPROVED][contractAddress].name = name;
        tokens[TokenStatus.APPROVED][contractAddress].symbol = symbol;
        tokens[TokenStatus.APPROVED][contractAddress].logoURI = logoURI;
        tokens[TokenStatus.APPROVED][contractAddress].decimals = decimals;
    }
}
