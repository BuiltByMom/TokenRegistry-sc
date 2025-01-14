// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokentroller.sol";
import "./interfaces/ITokenRegistry.sol";
import "./interfaces/ITokenMetadataRegistry.sol";

contract TokenRegistry is ITokenRegistry {
    // Main token storage - chainID => token address => status index => token info
    // Status: 0 = pending, 1 = approved, 2 = rejected
    mapping(uint256 => mapping(address => mapping(uint8 => Token))) public tokens;

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
            tokens[chainID][contractAddress][0].contractAddress == address(0) &&
                tokens[chainID][contractAddress][1].contractAddress == address(0),
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
        if (tokens[chainID][contractAddress][2].contractAddress != address(0)) {
            delete tokens[chainID][contractAddress][2];
            rejectedTokenCount[chainID]--;
        } else {
            tokenAddresses[chainID].push(contractAddress);
        }

        tokens[chainID][contractAddress][0] = newToken;
        pendingTokenCount[chainID]++;

        emit TokenAdded(contractAddress, name, symbol, logoURI, decimals, chainID);
    }

    function addTokenWithMetadata(
        uint256 chainID,
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals,
        MetadataInput[] calldata metadata
    ) public {
        // First add the token using existing logic
        addToken(chainID, contractAddress, name, symbol, logoURI, decimals);

        // Then set the metadata using the state variable
        ITokenMetadataRegistry(metadataRegistry).setMetadataBatch(contractAddress, chainID, metadata);
    }

    function approveToken(uint256 chainID, address contractAddress) public {
        require(tokens[chainID][contractAddress][0].contractAddress != address(0), "Token must be in pending state");
        require(
            ITokentroller(tokentroller).canApproveToken(msg.sender, contractAddress, chainID),
            "Failed to approve token"
        );

        Token memory token = tokens[chainID][contractAddress][0];
        delete tokens[chainID][contractAddress][0];
        tokens[chainID][contractAddress][1] = token;

        pendingTokenCount[chainID]--;
        approvedTokenCount[chainID]++;

        emit TokenApproved(contractAddress, chainID);
    }

    function rejectToken(uint256 chainID, address contractAddress, string calldata reason) public {
        require(tokens[chainID][contractAddress][0].contractAddress != address(0), "Token must be in pending state");
        require(
            ITokentroller(tokentroller).canRejectToken(msg.sender, contractAddress, chainID),
            "Failed to reject token"
        );

        Token memory token = tokens[chainID][contractAddress][0];
        delete tokens[chainID][contractAddress][0];
        tokens[chainID][contractAddress][2] = token;

        pendingTokenCount[chainID]--;
        rejectedTokenCount[chainID]++;

        emit TokenRejected(contractAddress, chainID, reason);
    }

    function listTokens(
        uint256 chainID,
        uint256 initialIndex,
        uint256 size,
        uint8 status
    ) external view returns (Token[] memory tokens_, uint256 finalIndex, bool hasMore) {
        require(size > 0, "Size must be greater than zero");
        require(status <= 2, "Invalid status");

        // Get the total count for the requested status
        uint256 totalStatusTokens;
        if (status == 0) totalStatusTokens = pendingTokenCount[chainID];
        else if (status == 1) totalStatusTokens = approvedTokenCount[chainID];
        else totalStatusTokens = rejectedTokenCount[chainID];

        // Early return if no tokens or invalid initial index
        if (totalStatusTokens == 0 || initialIndex >= totalStatusTokens) {
            return (new Token[](0), 0, false);
        }

        // Calculate optimal array size
        uint256 remainingTokens = totalStatusTokens - initialIndex;
        uint256 arraySize = size > remainingTokens ? remainingTokens : size;
        tokens_ = new Token[](arraySize);

        uint256 found; // Number of tokens found for the requested status
        uint256 statusCount; // Running count of tokens matching the status

        for (uint256 i = 0; i < tokenAddresses[chainID].length && found < arraySize; i++) {
            (Token memory token, bool exists) = _getTokenAtIndex(chainID, i, status);

            if (exists) {
                if (statusCount >= initialIndex) {
                    tokens_[found] = token;
                    found++;
                    finalIndex = i;
                }
                statusCount++;
            }
        }

        hasMore = (totalStatusTokens - initialIndex) > arraySize;
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
        uint8 status
    ) private view returns (Token memory token, bool exists) {
        address tokenAddress = tokenAddresses[chainID][index];
        token = tokens[chainID][tokenAddress][status];
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
        require(tokens[chainID][contractAddress][1].contractAddress != address(0), "Token must be approved");

        tokens[chainID][contractAddress][1].name = name;
        tokens[chainID][contractAddress][1].symbol = symbol;
        tokens[chainID][contractAddress][1].logoURI = logoURI;
        tokens[chainID][contractAddress][1].decimals = decimals;
    }
}
