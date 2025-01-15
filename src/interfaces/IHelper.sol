// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISharedTypes.sol";

interface IHelper {
    function addTokenWithMetadata(
        uint256 chainID,
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals,
        MetadataInput[] calldata metadata
    ) external;

    function proposeEditWithMetadata(
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals,
        uint256 chainID,
        MetadataInput[] calldata metadataUpdates
    ) external;
}
