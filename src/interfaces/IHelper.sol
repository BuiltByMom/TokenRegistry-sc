// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISharedTypes.sol";

interface IHelper {
    function addTokenWithMetadata(
        address contractAddress,
        string calldata logoURI,
        MetadataInput[] calldata metadata
    ) external;

    function proposeEditWithMetadata(
        address contractAddress,
        string calldata logoURI,
        MetadataInput[] calldata metadataUpdates
    ) external;
}
