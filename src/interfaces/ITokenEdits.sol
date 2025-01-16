// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISharedTypes.sol";

interface ITokenEdits {
    struct TokenEdit {
        address submitter;
        string logoURI;
        uint256 timestamp;
    }

    struct EditParams {
        uint256 initialIndex;
        uint256 size;
        uint256 totalEdits;
    }

    event EditProposed(address indexed contractAddress, address indexed submitter, string logoURI);
    event EditAccepted(address indexed contractAddress, uint256 indexed editIndex);
    event EditRejected(address indexed contractAddress, uint256 indexed editIndex, string reason);
    event TokentrollerUpdated(address indexed newTokentroller);

    function proposeEdit(address contractAddress, string calldata logoURI) external;

    function acceptEdit(address contractAddress, uint256 editIndex) external;

    function rejectEdit(address contractAddress, uint256 editIndex, string calldata reason) external;

    function listEdits(uint256 initialIndex, uint256 size) external view returns (string[] memory edits, uint256 total);

    function getTokensWithEditsCount() external view returns (uint256);

    function getTokenEdits(address token) external view returns (string[] memory);

    function getEditCount(address token) external view returns (uint256);

    function updateTokentroller(address newTokentroller) external;
}
