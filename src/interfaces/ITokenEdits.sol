// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISharedTypes.sol";

interface ITokenEdits {
    struct TokenEdit {
        address token;
        uint256[] editIds;
        MetadataInput[][] updates;
    }

    event EditProposed(address indexed contractAddress, address indexed submitter, MetadataInput[] metadata);
    event EditAccepted(address indexed contractAddress, uint256 editIndex);
    event EditRejected(address indexed contractAddress, uint256 editIndex, string reason);

    function proposeEdit(address contractAddress, MetadataInput[] calldata metadata) external;
    function acceptEdit(address contractAddress, uint256 editIndex) external;
    function rejectEdit(address contractAddress, uint256 editIndex, string calldata reason) external;
    function getTokensWithEditsCount() external view returns (uint256);
    function getTokenEdits(
        address token
    ) external view returns (uint256[] memory editIds, MetadataInput[][] memory updates);
    function getEditCount(address token) external view returns (uint256);
    function listEdits(
        uint256 initialIndex,
        uint256 size
    ) external view returns (TokenEdit[] memory tokenEdits, uint256 total);
    function updateTokentroller(address newTokentroller) external;
}
