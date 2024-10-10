// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokentroller {
    function canFastTrackToken(address _sender, address _contractAddress, uint256 _chainID) external returns (bool);
    function canRejectToken(address _sender, address _contractAddress, uint256 _chainID) external returns (bool);
    function canUpdateTokentroller(address _newTokentroller) external returns (bool);
    function canAddToken(address _newToken, uint256 _chainID) external returns (bool);
    function canUpdateToken(address _contractAddress, uint256 _chainID) external returns (bool);
    function canAcceptTokenEdit(address _contractAddress, uint256 _editIndex, uint256 _chainID) external returns (bool);
    function delayToOptimisticApproval() external view returns (uint256);
}

contract TokenRegistry {
    /**********************************************************************************************
     * Token struct represents the essential information for a token in the registry.
     * It includes details such as contract address, submitter, name, logo URI, symbol, and decimals.
     * The status field indicates the approval state of the token:
     * - 0: Pending approval
     * - 1: Approved
     * - 2: Rejected
     * The optimisticApprovalTime is the timestamp when the token becomes eligible for
     * optimistic approval (submission time + delayToOptimisticApproval)
     *********************************************************************************************/
    struct Token {
        address contractAddress; // Address of the token
        address submitter; // Address of the submitter
        string name; // Name of the token
        string logoURI; // URI of the token's logo
        string symbol; // Symbol of the token
        uint8 decimals; // Number of decimals for the token
        uint8 status; // Status indicating whether the token is pending approval [0], approved [1], rejected [2]
        uint256 chainID; // Chain ID of the token
        uint256 optimisticApprovalTime; // Timestamp when the token is optimistic approved
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
    event TokenEditsCleared(address indexed contractAddress, uint256 chainID); // Event for token edits clearing
    event TokenEditAccepted(address indexed contractAddress, uint256 indexed editIndex, uint256 chainID); // Event for token edit acceptance
    event TokentrollerUpdated(address indexed newCouncil); // Event for tokentroller update

    /**********************************************************************************************
     * __     __         _       _     _           
     * \ \   / /_ _ _ __(_) __ _| |__ | | ___  ___ 
     *  \ \ / / _` | '__| |/ _` | '_ \| |/ _ \/ __|
     *   \ V / (_| | |  | | (_| | |_) | |  __/\__ \
     *    \_/ \__,_|_|  |_|\__,_|_.__/|_|\___||___/
     *********************************************************************************************/
    mapping(uint256 => mapping(address => Token)) public tokens; // Mapping to store tokens by their contract address for a specific chainID
    mapping(uint256 => address[]) public tokenAddresses; // Array to store all token addresses for a specific chainID
    mapping(uint256 => mapping(address => mapping(uint256 => Token))) public editsOnTokens; // Mapping to store tokens by their contract address that are pending edits for a specific chainID
    mapping(uint256 => mapping(address => uint256)) public editCount; // Mapping to store the number of edits on a token for a specific chainID
    address public tokentroller; // Address of the governing council


    /**********************************************************************************************
     * @dev Constructor for the TokenRegistry contract
     * @param _tokentroller The address of the tokentroller contract that manages token approvals
     * @notice Initializes the contract with the tokentroller address
     * @notice The tokentroller is responsible for managing token approvals and rejections
     * @notice This constructor sets up the initial state for the token registry
     *********************************************************************************************/
    constructor(address _tokentroller) {
        tokentroller = _tokentroller;
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
     * @notice Sets an optimistic approval time based on the Tokentroller's delay setting
     *********************************************************************************************/
    function addToken(address _contractAddress, string memory _name, string memory _symbol, string memory _logoURI, uint8 _decimals, uint256 _chainID) public {
        require(tokens[_chainID][_contractAddress].contractAddress == address(0), "Token already exists");
        require(_contractAddress != address(0), "New token address cannot be zero");
        require(ITokentroller(tokentroller).canAddToken(_contractAddress, _chainID), "Failed to add token");

        uint256 delayToOptimisticApproval = ITokentroller(tokentroller).delayToOptimisticApproval();

        Token memory newToken = Token({
            contractAddress: _contractAddress,
            submitter: msg.sender,
            name: _name,
            logoURI: _logoURI,
            symbol: _symbol,
            decimals: _decimals,
            status: 0,
            chainID: _chainID,
            optimisticApprovalTime: block.timestamp + delayToOptimisticApproval
        });

        tokens[_chainID][_contractAddress] = newToken;
        tokenAddresses[_chainID].push(_contractAddress);
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
        require(tokens[_chainID][_contractAddress].contractAddress != address(0), "Token does not exist");
        require(_contractAddress != address(0), "New token address cannot be zero");
        require(ITokentroller(tokentroller).canUpdateToken(_contractAddress, _chainID), "Failed to update token");

        uint256 delayToOptimisticApproval = ITokentroller(tokentroller).delayToOptimisticApproval();

        // If the token is in pending mode & the token is not optimistic approved and the submitter is the same as the original submitter
        bool isOptimisticApproved = block.timestamp >= tokens[_chainID][_contractAddress].optimisticApprovalTime;
        if (
            tokens[_chainID][_contractAddress].status == 0
            && !isOptimisticApproved
            && tokens[_chainID][_contractAddress].submitter == msg.sender
        ) {
            tokens[_chainID][_contractAddress].name = _name;
            tokens[_chainID][_contractAddress].symbol = _symbol;
            tokens[_chainID][_contractAddress].logoURI = _logoURI;
            tokens[_chainID][_contractAddress].decimals = _decimals;
            tokens[_chainID][_contractAddress].optimisticApprovalTime = block.timestamp + delayToOptimisticApproval; // Reset the optimistic approval time to now
        } else {
            uint256 newIndex = ++editCount[_chainID][_contractAddress];
            editsOnTokens[_chainID][_contractAddress][newIndex] = Token({
                contractAddress: _contractAddress,
                submitter: msg.sender,
                name: _name,
                logoURI: _logoURI,
                symbol: _symbol,
                decimals: _decimals,
                status: 0,
                chainID: _chainID,
                optimisticApprovalTime: block.timestamp + delayToOptimisticApproval
            });
        }

        emit UpdateSuggested(_contractAddress, _name, _symbol, _logoURI, _decimals, _chainID);  
    }

    /**********************************************************************************************
     * @dev Accepts a token edit and updates the token registry accordingly
     * @param _contractAddress The contract address of the token to accept the edit for
     * @param _editIndex The index of the edit to accept
     * @notice This function can only be called by the tokentroller
     * @notice The token must exist in the registry and the edit index must be valid
     * @notice If the edit is approved or past the optimistic approval time, it updates the token
     * @notice Removes all edits before the accepted one and shifts remaining edits
     * @notice Updates the edit count for the token
     * @notice Emits a TokenEditAccepted event upon successful acceptance
     *********************************************************************************************/
    function acceptTokenEdit(address _contractAddress, uint256 _editIndex, uint256 _chainID) public {
        require(tokens[_chainID][_contractAddress].contractAddress != address(0), "Token does not exist");
        require(_editIndex <= editCount[_chainID][_contractAddress], "Invalid edit index");
        require(ITokentroller(tokentroller).canAcceptTokenEdit(_contractAddress, _chainID, _editIndex), "Failed to accept token edit");

        Token memory edit = editsOnTokens[_chainID][_contractAddress][_editIndex];
        if (edit.status == 1 || (edit.status == 0 && block.timestamp >= edit.optimisticApprovalTime)) {
            tokens[_chainID][_contractAddress] = edit; // Update the original token with the latest approved edit
            tokens[_chainID][_contractAddress].status = 1; // Set status to approved
        } else {
            revert("Edit is not approved or past the optimistic approval time");
        }

        // Remove all edits before this one
        for (uint256 i = 1; i < _editIndex; i++) {
            delete editsOnTokens[_chainID][_contractAddress][i];
        }

        // Shift remaining edits
        uint256 newEditCount = 0;
        for (uint256 i = _editIndex + 1; i <= editCount[_chainID][_contractAddress]; i++) {
            newEditCount++;
            editsOnTokens[_chainID][_contractAddress][newEditCount] = editsOnTokens[_chainID][_contractAddress][i];
            delete editsOnTokens[_chainID][_contractAddress][i];
        }

        // Update edit count
        editCount[_chainID][_contractAddress] = newEditCount;

        emit TokenEditAccepted(_contractAddress, _editIndex, _chainID);
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
     * @dev Lists all tokens in the registry with pagination, regardless of approval status.
     * @param initialIndex The starting index for token retrieval.
     * @param size The number of tokens to retrieve.
     * @return Token[] - An array of Token structs for the specified range.
     * @return uint256 - The index of the last token retrieved.
     * @notice This function returns all tokens, including those that are:
     *         1. Pending (status == 0)
     *         2. Approved (status == 1)
     *         3. Rejected (status == 2)
     *********************************************************************************************/
    function listAllTokens(uint256 _chainID, uint256 _initialIndex, uint256 _size) public view returns (Token[] memory, uint256) {
        require(_size > 0, "Size must be greater than zero");
        require(_initialIndex < tokenAddresses[_chainID].length, "Initial index out of range");

        uint256 remainingTokens = tokenAddresses[_chainID].length - _initialIndex;
        uint256 actualSize = _size < remainingTokens ? _size : remainingTokens;

        Token[] memory pageTokens = new Token[](actualSize);
        uint256 finalIndex = _initialIndex + actualSize - 1;

        for (uint256 i = 0; i < actualSize; i++) {
            pageTokens[i] = tokens[_chainID][tokenAddresses[_chainID][_initialIndex + i]];
        }

        return (pageTokens, finalIndex);
    }

	/**********************************************************************************************
     * @dev Lists approved tokens in the registry with pagination.
     * @param initialIndex The starting index for token retrieval.
     * @param size The number of tokens to retrieve.
     * @return Token[]  - An array of Token structs for the specified range.
     * @return uint256 - The index of the last token retrieved.
     * @notice This function returns tokens that are either:
     *         1. Pending but past the optimistic approval period (status == 0)
     *         2. Approved (status == 1)
     * @notice Tokens that are rejected or in the optimistic approval period are not included.
	 *********************************************************************************************/
    function listApprovedTokens(uint256 _chainID, uint256 _initialIndex, uint256 _size) public view returns (Token[] memory, uint256) {
        require(_size > 0, "Size must be greater than zero");
        require(_initialIndex < tokenAddresses[_chainID].length, "Initial index out of range");

        Token[] memory pageTokens = new Token[](_size);
        uint256 count = 0;
        uint256 finalIndex = _initialIndex;

        // Loop through the token addresses and add the tokens to the pageTokens array
        for (uint256 i = _initialIndex; i < tokenAddresses[_chainID].length && count < _size; i++) {
            Token memory token = tokens[_chainID][tokenAddresses[_chainID][i]];
            if (token.contractAddress != address(0) && (token.status == 1 || (token.status == 0 && block.timestamp >= token.optimisticApprovalTime))) {
                pageTokens[count] = token;
                count++;
                finalIndex = i;
            }
        }

        // If we didn't fill the entire array, create a new one with the correct size
        if (count < _size) {
            Token[] memory resizedTokens = new Token[](count);
            for (uint256 i = 0; i < count; i++) {
                resizedTokens[i] = pageTokens[i];
            }
            return (resizedTokens, finalIndex);
        }

        return (pageTokens, finalIndex);
    }

    /**********************************************************************************************
     * @dev Lists all rejected tokens in the registry with pagination.
     * @param initialIndex The starting index for token retrieval.
     * @param size The number of tokens to retrieve.
     * @return Token[] - An array of rejected Token structs for the specified range.
     * @return uint256 - The index of the last token retrieved.
     * @notice This function returns only tokens with status == 2 (rejected).
     * @notice If there are fewer rejected tokens than the requested size, it returns all available.
     *********************************************************************************************/
    function listRejectedTokens(uint256 _chainID, uint256 _initialIndex, uint256 _size) public view returns (Token[] memory, uint256) {
        require(_size > 0, "Size must be greater than zero");
        require(_initialIndex < tokenAddresses[_chainID].length, "Initial index out of range");

        Token[] memory pageTokens = new Token[](_size);
        uint256 count = 0;
        uint256 finalIndex = _initialIndex;

        for (uint256 i = _initialIndex; i < tokenAddresses[_chainID].length && count < _size; i++) {
            Token memory token = tokens[_chainID][tokenAddresses[_chainID][i]];
            if (token.status == 2) {
                pageTokens[count] = token;
                count++;
                finalIndex = i;
            }
        }

        // If we didn't fill the entire array, create a new one with the correct size
        if (count < _size) {
            Token[] memory resizedTokens = new Token[](count);
            for (uint256 i = 0; i < count; i++) {
                resizedTokens[i] = pageTokens[i];
            }
            return (resizedTokens, finalIndex);
        }

        return (pageTokens, finalIndex);
    }

    /**********************************************************************************************
     * @dev Lists all pending tokens in the registry with pagination.
     * @param initialIndex The starting index for token retrieval.
     * @param size The number of tokens to retrieve.
     * @return Token[] - An array of pending Token structs for the specified range.
     * @return uint256 - The index of the last token retrieved.
     * @notice This function returns only tokens with status == 0 (pending).
     * @notice If there are fewer pending tokens than the requested size, it returns all available.
     *********************************************************************************************/
    function listPendingTokens(uint256 _chainID, uint256 _initialIndex, uint256 _size) public view returns (Token[] memory, uint256) {
        require(_size > 0, "Size must be greater than zero");
        require(_initialIndex < tokenAddresses[_chainID].length, "Initial index out of range");

        Token[] memory pageTokens = new Token[](_size);
        uint256 count = 0;
        uint256 finalIndex = _initialIndex;

        for (uint256 i = _initialIndex; i < tokenAddresses[_chainID].length && count < _size; i++) {
            Token memory token = tokens[_chainID][tokenAddresses[_chainID][i]];
            if (token.status == 0) {
                pageTokens[count] = token;
                count++;
                finalIndex = i;
            }
        }

        // If we didn't fill the entire array, create a new one with the correct size
        if (count < _size) {
            Token[] memory resizedTokens = new Token[](count);
            for (uint256 i = 0; i < count; i++) {
                resizedTokens[i] = pageTokens[i];
            }
            return (resizedTokens, finalIndex);
        }

        return (pageTokens, finalIndex);
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
        require(tokens[_chainID][_contractAddress].contractAddress != address(0), "Token does not exist");
        require(tokens[_chainID][_contractAddress].status == 0, "Token is already approved or rejected");
        require(ITokentroller(tokentroller).canFastTrackToken(msg.sender, _contractAddress, _chainID), "Failed to fast-track token");

        // Proceed to approve the token
        tokens[_chainID][_contractAddress].status = 1;

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
        require(tokens[_chainID][_contractAddress].contractAddress != address(0), "Token does not exist");
        require(ITokentroller(tokentroller).canRejectToken(msg.sender, _contractAddress, _chainID), "Failed to reject token");

        // Proceed to reject the token
        tokens[_chainID][_contractAddress].status = 2;

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
}
