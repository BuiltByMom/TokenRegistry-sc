// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ISharedTypes.sol";

interface ITokentroller {
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);

    function canApproveToken(address sender, address contractAddress) external view returns (bool);
    function canRejectToken(address sender, address contractAddress) external view returns (bool);
    function canAddToken(address sender, address contractAddress) external view returns (bool);
    function canUpdateToken(address sender, address contractAddress) external view returns (bool);
    function canProposeTokenEdit(address sender, address contractAddress) external view returns (bool);

    function canAcceptTokenEdit(
        address sender,
        address contractAddress,
        uint256 editIndex
    ) external view returns (bool);
    function canRejectTokenEdit(address sender, address token, uint256 editIndex) external view returns (bool);

    function canAddMetadataField(address sender, string calldata name) external view returns (bool);
    function canUpdateMetadataField(address sender, string calldata name, bool isActive) external view returns (bool);
    function canSetMetadata(address sender, address token, string calldata field) external view returns (bool);

    function canUpdateMetadata(address sender, address token) external view returns (bool);

    function canProposeMetadataEdit(
        address sender,
        address token,
        MetadataInput[] calldata updates
    ) external view returns (bool);

    function canAcceptMetadataEdit(address sender, address token, uint256 editIndex) external view returns (bool);

    function canRejectMetadataEdit(address sender, address token, uint256 editIndex) external view returns (bool);
}
