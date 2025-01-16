// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISharedTypes.sol";

interface ITokenMetadataEdits {
    struct MetadataEditProposal {
        address submitter;
        MetadataInput[] updates;
        uint256 timestamp;
    }

    struct MetadataEditInfo {
        address token;
        address submitter;
        MetadataInput[] updates;
        uint256 editIndex;
        uint256 timestamp;
    }

    event MetadataEditProposed(address indexed token, address submitter, MetadataInput[] updates);
    event MetadataEditAccepted(address indexed token, uint256 indexed editIndex);
    event MetadataEditRejected(address indexed token, uint256 indexed editIndex, string reason);
    event TokentrollerUpdated(address indexed newTokentroller);

    function proposeMetadataEdit(address token, MetadataInput[] calldata updates) external;
    function acceptMetadataEdit(address token, uint256 editIndex) external;
    function rejectMetadataEdit(address token, uint256 editIndex, string calldata reason) external;
    function listAllEdits(
        uint256 initialIndex,
        uint256 size
    ) external view returns (MetadataEditInfo[] memory edits, uint256 finalIndex, bool hasMore);
    function tokensMetadataWithEditsLength() external view returns (uint256);
    function getTokensMetadataWithEdits(uint256 index) external view returns (address);
    function getEditCount(address token) external view returns (uint256);
    function getEditProposal(address token, uint256 editIndex) external view returns (MetadataEditProposal memory);
    function updateTokentroller(address newTokentroller) external;
}
