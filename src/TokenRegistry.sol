// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokentroller.sol";
import "./interfaces/ITokenRegistry.sol";
import "./interfaces/ITokenMetadataRegistry.sol";

contract TokenRegistry is ITokenRegistry {
    // Main token storage - status => chainID => token address => token info
    mapping(TokenStatus => mapping(uint256 => mapping(address => Token))) public tokens;

    // Token addresses per chain
    mapping(uint256 => address[]) public tokenAddresses;

    // Token counts per status per chain
    mapping(uint256 => uint256) public pendingTokenCount;
    mapping(uint256 => uint256) public approvedTokenCount;
    mapping(uint256 => uint256) public rejectedTokenCount;

    // Governance
    address public tokentroller;
    address public metadataRegistry;

    constructor(address _tokentroller, address _metadataRegistry) {
        tokentroller = _tokentroller;
        metadataRegistry = _metadataRegistry;
    }

    function addToken(
        uint256 chainID,
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals
    ) public {
        require(
            tokens[TokenStatus.PENDING][chainID][contractAddress].contractAddress == address(0) &&
                tokens[TokenStatus.APPROVED][chainID][contractAddress].contractAddress == address(0),
            "Token already exists in pending or approved state"
        );
        require(contractAddress != address(0), "New token address cannot be zero");
        require(ITokentroller(tokentroller).canAddToken(msg.sender, contractAddress, chainID), "Failed to add token");

        Token memory newToken = Token({
            contractAddress: contractAddress,
            submitter: msg.sender,
            name: name,
            logoURI: logoURI,
            symbol: symbol,
            decimals: decimals,
            chainID: chainID
        });

        // If token was previously rejected, update it instead of adding new entry
        if (tokens[TokenStatus.REJECTED][chainID][contractAddress].contractAddress != address(0)) {
            delete tokens[TokenStatus.REJECTED][chainID][contractAddress];
            rejectedTokenCount[chainID]--;
        } else {
            tokenAddresses[chainID].push(contractAddress);
        }

        tokens[TokenStatus.PENDING][chainID][contractAddress] = newToken;
        pendingTokenCount[chainID]++;

        emit TokenAdded(contractAddress, name, symbol, logoURI, decimals, chainID);
    }

    function approveToken(uint256 chainID, address contractAddress) public {
        require(
            tokens[TokenStatus.PENDING][chainID][contractAddress].contractAddress != address(0),
            "Token must be in pending state"
        );
        require(
            ITokentroller(tokentroller).canApproveToken(msg.sender, contractAddress, chainID),
            "Failed to approve token"
        );

        Token memory token = tokens[TokenStatus.PENDING][chainID][contractAddress];
        delete tokens[TokenStatus.PENDING][chainID][contractAddress];
        tokens[TokenStatus.APPROVED][chainID][contractAddress] = token;

        pendingTokenCount[chainID]--;
        approvedTokenCount[chainID]++;

        emit TokenApproved(contractAddress, chainID);
    }

    function rejectToken(uint256 chainID, address contractAddress, string calldata reason) public {
        require(
            tokens[TokenStatus.PENDING][chainID][contractAddress].contractAddress != address(0),
            "Token must be in pending state"
        );
        require(
            ITokentroller(tokentroller).canRejectToken(msg.sender, contractAddress, chainID),
            "Failed to reject token"
        );

        Token memory token = tokens[TokenStatus.PENDING][chainID][contractAddress];
        delete tokens[TokenStatus.PENDING][chainID][contractAddress];
        tokens[TokenStatus.REJECTED][chainID][contractAddress] = token;

        pendingTokenCount[chainID]--;
        rejectedTokenCount[chainID]++;

        emit TokenRejected(contractAddress, chainID, reason);
    }

    function listTokens(
        uint256 chainID,
        uint256 offset,
        uint256 limit,
        TokenStatus status
    ) external view returns (Token[] memory tokens_, uint256 total) {
        require(limit > 0, "Limit must be greater than zero");

        // Get the total count for the requested status
        total = (status == TokenStatus.PENDING)
            ? pendingTokenCount[chainID]
            : (status == TokenStatus.APPROVED)
                ? approvedTokenCount[chainID]
                : rejectedTokenCount[chainID];

        // Early return if no tokens or invalid initial index
        if (total == 0 || offset >= total) {
            return (new Token[](0), total);
        }

        // Calculate optimal array size
        uint256 size = (offset + limit > total) ? total - offset : limit;
        tokens_ = new Token[](size);

        uint256 found; // Number of tokens found for the requested status
        uint256 statusCount; // Running count of tokens matching the status

        for (uint256 i = 0; i < tokenAddresses[chainID].length && found < size; i++) {
            (Token memory token, bool exists) = _getTokenAtIndex(chainID, i, status);

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

    function getTokenCounts(
        uint256 chainID
    ) external view returns (uint256 pending, uint256 approved, uint256 rejected) {
        return (pendingTokenCount[chainID], approvedTokenCount[chainID], rejectedTokenCount[chainID]);
    }

    function tokenCount(uint256 chainID) external view returns (uint256) {
        return tokenAddresses[chainID].length;
    }

    function _getTokenAtIndex(
        uint256 chainID,
        uint256 index,
        TokenStatus status
    ) private view returns (Token memory token, bool exists) {
        address tokenAddress = tokenAddresses[chainID][index];
        token = tokens[status][chainID][tokenAddress];
        exists = token.contractAddress != address(0);
    }

    function updateTokentroller(address newTokentroller) public {
        require(msg.sender == tokentroller, "Only tokentroller can update");
        tokentroller = newTokentroller;
        emit TokentrollerUpdated(newTokentroller);
    }

    function updateToken(
        uint256 chainID,
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals
    ) external {
        require(ITokentroller(tokentroller).canUpdateToken(msg.sender, contractAddress, chainID), "Not authorized");
        require(
            tokens[TokenStatus.APPROVED][chainID][contractAddress].contractAddress != address(0),
            "Token must be approved"
        );

        tokens[TokenStatus.APPROVED][chainID][contractAddress].name = name;
        tokens[TokenStatus.APPROVED][chainID][contractAddress].symbol = symbol;
        tokens[TokenStatus.APPROVED][chainID][contractAddress].logoURI = logoURI;
        tokens[TokenStatus.APPROVED][chainID][contractAddress].decimals = decimals;
    }
}
