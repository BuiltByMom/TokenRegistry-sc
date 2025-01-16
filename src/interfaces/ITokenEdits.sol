// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISharedTypes.sol";

interface ITokenEdits {
    struct TokenEdit {
        address submitter;
        string name;
        string symbol;
        string logoURI;
        uint8 decimals;
        uint256 timestamp;
    }

    struct EditParams {
        uint256 initialIndex;
        uint256 size;
        uint256 totalEdits;
    }

    event EditProposed(
        address indexed contractAddress,
        address indexed submitter,
        string name,
        string symbol,
        string logoURI,
        uint8 decimals
    );
    event EditAccepted(address indexed contractAddress, uint256 indexed editIndex);
    event EditRejected(address indexed contractAddress, uint256 indexed editIndex, string reason);
    event TokentrollerUpdated(address indexed newTokentroller);

    function proposeEdit(
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals
    ) external;

    function acceptEdit(address contractAddress, uint256 editIndex) external;

    function rejectEdit(address contractAddress, uint256 editIndex, string calldata reason) external;

    function listEdits(
        uint256 initialIndex,
        uint256 size
    ) external view returns (TokenEdit[] memory edits, uint256 finalIndex, bool hasMore);

    function getTokensWithEditsCount() external view returns (uint256);

    function getTokenWithEdits(uint256 index) external view returns (address);

    function getEditCount(address token) external view returns (uint256);
}
