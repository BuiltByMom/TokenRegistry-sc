// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITokentroller.sol";
import "./interfaces/ITokenMetadataRegistry.sol";
import "./interfaces/ISharedTypes.sol";

contract TokenRegistry {
    /**********************************************************************************************
     * Token struct represents the essential information for a token in the registry.
     * It includes details such as contract address, submitter, name, logo URI, symbol, and decimals.
     *********************************************************************************************/
    struct Token {
        address contractAddress; // Address of the token
        address submitter; // Address of the submitter
        string name; // Name of the token
        string logoURI; // URI of the token's logo
        string symbol; // Symbol of the token
        uint8 decimals; // Number of decimals for the token
        uint256 chainID; // Chain ID of the token
    }

    struct TokenEdit {
        address contractAddress;
        address submitter;
        string name;
        string logoURI;
        string symbol;
        uint8 decimals;
        uint256 chainID;
        uint256 editIndex;
    }

    /**********************************************************************************************
     *  _____                 _       
     * | ____|_   _____ _ __ | |_ ___ 
     * |  _| \ \ / / _ \ '_ \| __/ __|
     * | |___ \ V /  __/ | | | |_\__ \
     * |_____| \_/ \___|_| |_|\__|___/
     *********************************************************************************************/
    event TokenAdded(address indexed contractAddress, string name, string symbol, string logoURI, uint8 decimals, uint256 chainID); // Event for token addition
    event UpdateSuggested(address indexed contractAddress, string name, string symbol, string logoURI, uint8 decimals, uint256 chainID); // Event for token update
    event TokenApproved(address indexed contractAddress, uint256 chainID); // Event for token approval
    event TokenRejected(address indexed contractAddress, uint256 chainID); // Event for token rejection
    event TokenEditAccepted(address indexed contractAddress, uint256 indexed editIndex, uint256 chainID); // Event for token edit acceptance
    event TokentrollerUpdated(address indexed newCouncil); // Event for tokentroller update
    event TokenEditRejected(address indexed contractAddress, uint256 indexed editIndex, uint256 chainID); // Event for token edit rejection

    /**********************************************************************************************
     * __     __         _       _     _           
     * \ \   / /_ _ _ __(_) __ _| |__ | | ___  ___ 
     *  \ \ / / _` | '__| |/ _` | '_ \| |/ _ \/ __|
     *   \ V / (_| | |  | | (_| | |_) | |  __/\__ \
     *    \_/ \__,_|_|  |_|\__,_|_.__/|_|\___||___/
     *********************************************************************************************/
    mapping(uint256 => mapping(address => mapping(uint8 => Token))) public tokens; // Mapping to store tokens by their contract address for a specific chainID

    mapping(uint256 => address[]) public tokenAddresses; // Array to store all token addresses for a specific chainID
    mapping(uint256 => mapping(address => mapping(uint256 => Token))) public editsOnTokens; // Mapping to store tokens by their contract address that are pending edits for a specific chainID
    mapping(uint256 => mapping(address => uint256)) public editCount; // Mapping to store the number of edits on a token for a specific chainID
    address public tokentroller; // Address of the governing council

    mapping(uint256 => uint256) public pendingTokenCount; // Count of pending tokens per chain
    mapping(uint256 => uint256) public approvedTokenCount; // Count of approved tokens per chain
    mapping(uint256 => uint256) public rejectedTokenCount; // Count of rejected tokens per chain

    ITokenMetadataRegistry public metadataRegistry;

    // Add mapping to track tokens with pending edits
    mapping(uint256 => address[]) public tokensWithEdits;

    /**********************************************************************************************
     * @dev Constructor for the TokenRegistry contract
     * @param _tokentroller The address of the tokentroller contract that manages token approvals
     * @notice Initializes the contract with the tokentroller address
     * @notice The tokentroller is responsible for managing token approvals and rejections
     * @notice This constructor sets up the initial state for the token registry
     *********************************************************************************************/
    constructor(address _tokentroller, address _metadataRegistry) {
        tokentroller = _tokentroller;
        metadataRegistry = ITokenMetadataRegistry(_metadataRegistry);
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
     * @dev Adds a new token to the registry
     * @param _contractAddress The contract address of the token
     * @param _name The name of the token
     * @param _symbol The symbol or ticker of the token
     * @param _logoURI The URI of the token's logo
     * @param _decimals The number of decimal places for the token
     * @notice Anyone can call this function to submit a new token for consideration
     * @notice The token is initially set to a pending status
     * @notice Emits a TokenAdded event upon successful addition
     * @notice Requires the token to not already exist and have a valid address
     * @notice Checks with the Tokentroller if the token can be added
     *********************************************************************************************/
    function addToken(address _contractAddress, string memory _name, string memory _symbol, string memory _logoURI, uint8 _decimals, uint256 _chainID) public {
        require(tokens[_chainID][_contractAddress][0].contractAddress == address(0), "Token already exists");
        require(_contractAddress != address(0), "New token address cannot be zero");
        require(ITokentroller(tokentroller).canAddToken(_contractAddress, _chainID), "Failed to add token");

        Token memory newToken = Token({
            contractAddress: _contractAddress,
            submitter: msg.sender,
            name: _name,
            logoURI: _logoURI,
            symbol: _symbol,
            decimals: _decimals,
            chainID: _chainID
        });

        tokens[_chainID][_contractAddress][0] = newToken;
        tokenAddresses[_chainID].push(_contractAddress);
        pendingTokenCount[_chainID]++;
        emit TokenAdded(_contractAddress, _name, _symbol, _logoURI, _decimals, _chainID);
    }

    /**********************************************************************************************
     * @dev Function to update a token in the registry or suggest an edit
     * @param _contractAddress The contract address of the token to update.
     * @param _name The new name of the token.
     * @param _symbol The new symbol of the token.
     * @param _logoURI The new URI of the token's logo.
     * @param _decimals The new number of decimal places for the token.
     * @notice This function can be called by anyone to update a token or suggest an edit.
     * @notice If the token is pending and the caller is the original submitter, the token is updated directly.
     * @notice Otherwise, a new edit is suggested and stored for later approval.
     * @notice Emits a UpdateSuggested event upon successful update or edit suggestion.
     *********************************************************************************************/
    function updateToken(address _contractAddress, string memory _name, string memory _symbol, string memory _logoURI, uint8 _decimals, uint256 _chainID) public {
        require(tokens[_chainID][_contractAddress][1].contractAddress != address(0), "Token does not exist");
        require(_contractAddress != address(0), "New token address cannot be zero");
        require(ITokentroller(tokentroller).canUpdateToken(_contractAddress, _chainID), "Failed to update token");
        
        uint256 newIndex = ++editCount[_chainID][_contractAddress];
        
        // Add to tokensWithEdits if this is the first edit
        if (newIndex == 1) {
            tokensWithEdits[_chainID].push(_contractAddress);
        }

        editsOnTokens[_chainID][_contractAddress][newIndex] = Token({
            contractAddress: _contractAddress,
            submitter: msg.sender,
            name: _name,
            logoURI: _logoURI,
            symbol: _symbol,
            decimals: _decimals,
            chainID: _chainID
        });

        emit UpdateSuggested(_contractAddress, _name, _symbol, _logoURI, _decimals, _chainID);
    }

    /**********************************************************************************************
     * @dev Accepts a token edit and updates the token registry accordingly
     * @param _contractAddress The contract address of the token to accept the edit for
     * @param _editIndex The index of the edit to accept
     * @notice This function can only be called by the tokentroller
     * @notice The token must exist in the registry and the edit index must be valid
     * @notice If the edit is approved, it updates the token
     * @notice Removes all edits before the accepted one and shifts remaining edits
     * @notice Updates the edit count for the token
     * @notice Emits a TokenEditAccepted event upon successful acceptance
     *********************************************************************************************/
    function acceptTokenEdit(address _contractAddress, uint256 _editIndex, uint256 _chainID) public {
        require(tokens[_chainID][_contractAddress][1].contractAddress != address(0), "Token does not exist");
        require(_editIndex <= editCount[_chainID][_contractAddress], "Invalid edit index");
        require(
            ITokentroller(tokentroller).canAcceptTokenEdit(_contractAddress, _chainID, _editIndex),
            "Failed to accept token edit"
        );

        Token memory edit = editsOnTokens[_chainID][_contractAddress][_editIndex];
        
        // Update the approved token with the edit
        tokens[_chainID][_contractAddress][1] = edit;

        // Clear all edits and remove from tracking
        for (uint256 i = 1; i <= editCount[_chainID][_contractAddress]; i++) {
            delete editsOnTokens[_chainID][_contractAddress][i];
        }
        editCount[_chainID][_contractAddress] = 0;
        
        _removeTokenFromEdits(_chainID, _contractAddress);

        emit TokenEditAccepted(_contractAddress, _editIndex, _chainID);
    }

        /**********************************************************************************************
     * @dev Function to reject a token edit
     * @param _contractAddress The contract address of the token to reject the edit for
     * @param _editIndex The index of the edit to reject
     * @param _chainID The chain ID of the token
     * @notice This function can only be called by the tokentroller
     * @notice The token must exist in the registry and the edit index must be valid
     * @notice Emits a TokenEditRejected event upon successful rejection
     *********************************************************************************************/
    function rejectTokenEdit(address _contractAddress, uint256 _editIndex, uint256 _chainID) public {
        require(tokens[_chainID][_contractAddress][1].contractAddress != address(0), "Token does not exist");
        require(_editIndex <= editCount[_chainID][_contractAddress], "Invalid edit index");
        require(
            ITokentroller(tokentroller).canRejectTokenEdit(msg.sender, _contractAddress, _chainID, _editIndex),
            "Failed to reject token edit"
        );

        // Clear the rejected edit
        delete editsOnTokens[_chainID][_contractAddress][_editIndex];
        editCount[_chainID][_contractAddress]--;

        // If no more edits, remove from tracking
        if (editCount[_chainID][_contractAddress] == 0) {
            _removeTokenFromEdits(_chainID, _contractAddress);
        }

        emit TokenEditRejected(_contractAddress, _editIndex, _chainID);
    }

    // Internal function to remove token from tokensWithEdits
    function _removeTokenFromEdits(uint256 _chainID, address _token) internal {
        address[] storage edits = tokensWithEdits[_chainID];
        for (uint256 i = 0; i < edits.length; i++) {
            if (edits[i] == _token) {
                // Move the last element to the position being deleted
                edits[i] = edits[edits.length - 1];
                edits.pop();
                break;
            }
        }
    }

    /**********************************************************************************************
     *     _                                        
     *    / \   ___ ___ ___  ___ ___  ___  _ __ ___ 
     *   / _ \ / __/ __/ _ \/ __/ __|/ _ \| '__/ __|
     *  / ___ \ (_| (_|  __/\__ \__ \ (_) | |  \__ \
     * /_/   \_\___\___\___||___/___/\___/|_|  |___/
     *
     * @dev These functions are for the public to get information about the tokens in the registry.
     * They do not require any special permissions or access control and are read-only.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Lists tokens in the registry with pagination, filtered by status.
     * @param _chainID The chain ID to retrieve tokens from.
     * @param _initialIndex The starting index for token retrieval.
     * @param _size The number of tokens to retrieve.
     * @param _status The status to filter by (0: Pending, 1: Approved, 2: Rejected)
     * @return Token[] - An array of Token structs for the specified range.
     * @return uint256 - The index of the last token retrieved.
     * @return bool - Indicates whether there are more tokens to retrieve.
     * @notice This function returns tokens filtered by their status:
     *         0: Pending
     *         1: Approved
     *         2: Rejected
     *********************************************************************************************/
    // Internal helper function to get token at index
    function _getTokenAtIndex(
        uint256 _chainID,
        uint256 _index,
        uint8 _status
    ) private view returns (Token memory token, bool exists) {
        address tokenAddress = tokenAddresses[_chainID][_index];
        token = tokens[_chainID][tokenAddress][_status];
        exists = token.contractAddress != address(0);
    }

    function listAllTokens(
        uint256 _chainID,
        uint256 _initialIndex,
        uint256 _size,
        uint8 _status
    ) public view returns (Token[] memory tokens_, uint256 finalIndex_, bool hasMore_) {
        require(_size > 0, "Size must be greater than zero");
        require(_status <= 2, "Invalid status");

        // Get the total count for the requested status
        uint256 totalStatusTokens;
        if (_status == 0) totalStatusTokens = pendingTokenCount[_chainID];
        else if (_status == 1) totalStatusTokens = approvedTokenCount[_chainID];
        else totalStatusTokens = rejectedTokenCount[_chainID];

        // Early return if no tokens or invalid initial index
        if (totalStatusTokens == 0 || _initialIndex >= totalStatusTokens) {
            return (new Token[](0), 0, false);
        }

        // Calculate optimal array size
        uint256 remainingTokens = totalStatusTokens - _initialIndex;
        uint256 arraySize = _size > remainingTokens ? remainingTokens : _size;
        tokens_ = new Token[](arraySize);

        uint256 found;        // Number of tokens found for the requested status
        uint256 statusCount;  // Running count of tokens matching the status
        
        for (uint256 i = 0; i < tokenAddresses[_chainID].length && found < arraySize; i++) {
            (Token memory token, bool exists) = _getTokenAtIndex(_chainID, i, _status);
            
            if (exists) {
                if (statusCount >= _initialIndex) {
                    tokens_[found] = token;
                    found++;
                    finalIndex_ = i;
                }
                statusCount++;
            }
        }

        hasMore_ = (totalStatusTokens - _initialIndex) > arraySize;
    }

    /**********************************************************************************************
     * @dev Retrieves the total number of tokens in the registry.
     * @return uint256 The total count of tokens registered.
     * @notice This function returns the total number of tokens that have been added to the
     *         registry, regardless of their current status (pending, approved, or rejected).
     *         It provides a quick way to get the size of the token list without pagination.
     *********************************************************************************************/
    function tokenCount(uint256 _chainID) public view returns (uint256) {
        return tokenAddresses[_chainID].length;
    }



    /**********************************************************************************************
     *  _____     _              _             _ _           
     * |_   _|__ | | _____ _ __ | |_ _ __ ___ | | | ___ _ __ 
     *   | |/ _ \| |/ / _ \ '_ \| __| '__/ _ \| | |/ _ \ '__|
     *   | | (_) |   <  __/ | | | |_| | | (_) | | |  __/ |   
     *   |_|\___/|_|\_\___|_| |_|\__|_|  \___/|_|_|\___|_|   
     *
     * @dev All the functions below are for the tokentroller to manage the tokens in the registry.
     * All the verifications are handled by the Tokentroller contract, which can be upgraded at
     * any time by the owner of the contract.
     *********************************************************************************************/

    /**********************************************************************************************
     * @dev Function for the tokentroller to fast-track a token
     * @param _contractAddress The address of the token to fast-track
     * @notice This function can only be called by the tokentroller
     * @notice The token must exist in the registry
     * @notice Emits a TokenApproved event upon successful fast-tracking
     *********************************************************************************************/
    function fastTrackToken(uint256 _chainID, address _contractAddress) public {
        require(tokens[_chainID][_contractAddress][0].contractAddress != address(0), "Token does not exist");
        require(ITokentroller(tokentroller).canFastTrackToken(msg.sender, _contractAddress, _chainID), "Failed to fast-track token");

        // Move token from status 0 to status 1
        Token memory token = tokens[_chainID][_contractAddress][0];
        delete tokens[_chainID][_contractAddress][0];
        
        tokens[_chainID][_contractAddress][1] = token;

        // Update counters
        pendingTokenCount[_chainID]--;
        approvedTokenCount[_chainID]++;

        emit TokenApproved(_contractAddress, _chainID);
    }

    /**********************************************************************************************
     * @dev Function for the tokentroller to reject a token
     * @param _contractAddress The address of the token to reject
     * @notice This function can only be called by the tokentroller
     * @notice The token must exist in the registry
     * @notice Emits a TokenRejected event upon successful rejection
     *********************************************************************************************/
    function rejectToken(uint256 _chainID, address _contractAddress) public {
        require(tokens[_chainID][_contractAddress][0].contractAddress != address(0), "Token does not exist");
        require(ITokentroller(tokentroller).canRejectToken(msg.sender, _contractAddress, _chainID), "Failed to reject token");

        Token memory token = tokens[_chainID][_contractAddress][0];
        
        // Remove from current status
        delete tokens[_chainID][_contractAddress][0];
        
        // Move to rejected status (2)
        tokens[_chainID][_contractAddress][2] = token;

        // Update counters
        pendingTokenCount[_chainID]--;
        rejectedTokenCount[_chainID]++;

        emit TokenRejected(_contractAddress, _chainID);
    }

    /**********************************************************************************************
     * @dev Function for the tokentroller to update the tokentroller address
     * @param _newTokentroller The address of the new tokentroller
     * @notice This function can only be called by the tokentroller
     * @notice The new tokentroller address must be valid
     * @notice Emits a TokentrollerUpdated event upon successful update
     *********************************************************************************************/
    function updateTokentroller(address _newTokentroller) public {
        require(msg.sender == tokentroller, "Only the tokentroller can call this function");
        tokentroller = _newTokentroller;
        emit TokentrollerUpdated(_newTokentroller);
    }

    /**********************************************************************************************
     * @dev Function to get the counts of tokens by status for a specific chain
     * @param _chainID The chain ID to retrieve token counts from
     * @return uint256 pending - The count of pending tokens
     * @return uint256 approved - The count of approved tokens
     * @return uint256 rejected - The count of rejected tokens
     * @notice This function returns the counts of tokens by status for a specific chain
     *********************************************************************************************/
    function getTokenCounts(uint256 _chainID) public view returns (uint256 pending, uint256 approved, uint256 rejected) {
        return (pendingTokenCount[_chainID], approvedTokenCount[_chainID], rejectedTokenCount[_chainID]);
    }

    /**********************************************************************************************
     * @dev Function to add a token with metadata
     * @param _contractAddress The contract address of the token
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @param _logoURI The URI of the token's logo
     * @param _decimals The number of decimal places for the token
     * @param _chainID The chain ID of the token
     * @param metadata An array of TokenMetadataRegistry.MetadataInput structs
     * @notice This function can only be called by the tokentroller
     * @notice The token must exist in the registry
     * @notice Emits a TokenAdded event upon successful addition
     * @notice Requires the token to not already exist and have a valid address
     * @notice Checks with the Tokentroller if the token can be added
     *********************************************************************************************/
    function addTokenWithMetadata(
        address _contractAddress,
        string memory _name,
        string memory _symbol,
        string memory _logoURI,
        uint8 _decimals,
        uint256 _chainID,
        MetadataInput[] calldata metadata
    ) public {
        // First add the token using existing logic
        addToken(_contractAddress, _name, _symbol, _logoURI, _decimals, _chainID);
        
        // Then set the metadata using the state variable
        metadataRegistry.setMetadataBatch(_contractAddress, _chainID, metadata);
    }

    // Add this helper struct to reduce stack variables
    struct EditParams {
        uint256 chainID;
        uint256 initialIndex;
        uint256 size;
        uint256 totalEdits;
    }

    function listAllEdits(
        uint256 _chainID,
        uint256 _initialIndex,
        uint256 _size
    ) public view returns (TokenEdit[] memory edits_, uint256 finalIndex_, bool hasMore_) {
        require(_size > 0, "Size must be greater than zero");

        // Count total edits
        uint256 totalEdits = 0;
        for (uint256 i = 0; i < tokensWithEdits[_chainID].length; i++) {
            totalEdits += editCount[_chainID][tokensWithEdits[_chainID][i]];
        }

        if (totalEdits == 0 || _initialIndex >= totalEdits) {
            return (new TokenEdit[](0), 0, false);
        }

        uint256 arraySize = _size > (totalEdits - _initialIndex) ? (totalEdits - _initialIndex) : _size;
        edits_ = new TokenEdit[](arraySize);

        EditParams memory params = EditParams({
            chainID: _chainID,
            initialIndex: _initialIndex,
            size: arraySize,
            totalEdits: totalEdits
        });

        (finalIndex_, hasMore_) = _getEdits(edits_, params);
    }

    function _getEdits(
        TokenEdit[] memory edits,
        EditParams memory params
    ) private view returns (uint256 finalIndex_, bool hasMore_) {
        uint256 found;
        uint256 editCounter;

        for (uint256 i = 0; i < tokensWithEdits[params.chainID].length && found < params.size; i++) {
            address tokenAddr = tokensWithEdits[params.chainID][i];
            uint256 tokenEditCount = editCount[params.chainID][tokenAddr];

            for (uint256 j = 1; j <= tokenEditCount && found < params.size; j++) {
                if (editCounter >= params.initialIndex) {
                    Token memory edit = editsOnTokens[params.chainID][tokenAddr][j];
                    if (edit.contractAddress != address(0)) {
                        edits[found] = TokenEdit({
                            contractAddress: edit.contractAddress,
                            submitter: edit.submitter,
                            name: edit.name,
                            logoURI: edit.logoURI,
                            symbol: edit.symbol,
                            decimals: edit.decimals,
                            chainID: edit.chainID,
                            editIndex: j
                        });
                        found++;
                        finalIndex_ = editCounter;
                    }
                }
                editCounter++;
            }
        }

        hasMore_ = (params.totalEdits - params.initialIndex) > params.size;
    }

    function tokensWithEditsLength(uint256 _chainID) public view returns (uint256) {
        return tokensWithEdits[_chainID].length;
    }

    function getTokensWithEdits(uint256 _chainID, uint256 _index) public view returns (address) {
        return tokensWithEdits[_chainID][_index];
    }
}

