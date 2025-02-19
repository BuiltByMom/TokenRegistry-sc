// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./ISharedTypes.sol";

interface ITokentroller {
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);
    event TrustedHelperAdded(address indexed helper);
    event TrustedHelperRemoved(address indexed helper);

    function canApproveToken(address sender, address contractAddress) external view returns (bool);
    function canRejectToken(address sender, address contractAddress) external view returns (bool);
    function canAddToken(address sender, address contractAddress) external view returns (bool);
    function canUpdateToken(address sender, address contractAddress) external view returns (bool);
    function canProposeTokenEdit(address sender, address contractAddress) external view returns (bool);

    function canAcceptTokenEdit(address sender, address contractAddress, uint256 editId) external view returns (bool);
    function canRejectTokenEdit(address sender, address contractAddress, uint256 editId) external view returns (bool);

    function canAddMetadataField(address sender, string calldata name) external view returns (bool);
    function canUpdateMetadataField(
        address sender,
        string calldata name,
        bool isActive,
        bool isRequired
    ) external view returns (bool);
    function canSetMetadata(
        address sender,
        address contractAddress,
        string calldata field
    ) external view returns (bool);

    function canUpdateMetadata(address sender, address contractAddress) external view returns (bool);

    function updateOwner(address newOwner) external;
    function updateMetadataTokentroller(address newTokentroller) external;
    function updateRegistryTokentroller(address newTokentroller) external;
    function addTrustedHelper(address helper) external;
    function removeTrustedHelper(address helper) external;
    function updateTokenEdits(address newTokenEdits) external;
}
