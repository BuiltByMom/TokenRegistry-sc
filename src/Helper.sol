// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IHelper.sol";
import "./interfaces/ITokenRegistry.sol";
import "./interfaces/ITokenMetadataRegistry.sol";
import "./interfaces/ITokenEdits.sol";
import "./interfaces/ITokenMetadataEdits.sol";

contract Helper is IHelper {
    address public tokenRegistry;
    address public tokenEdits;
    address public metadataEdits;
    address public metadataRegistry;

    constructor(address _tokenRegistry, address _tokenEdits, address _metadataRegistry, address _metadataEdits) {
        tokenRegistry = _tokenRegistry;
        tokenEdits = _tokenEdits;
        metadataRegistry = _metadataRegistry;
        metadataEdits = _metadataEdits;
    }

    function addTokenWithMetadata(
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals,
        MetadataInput[] calldata metadata
    ) public {
        // First add the token using existing logic
        ITokenRegistry(tokenRegistry).addToken(contractAddress, name, symbol, logoURI, decimals);

        // Then set the metadata using the state variable
        ITokenMetadataRegistry(metadataRegistry).setMetadataBatch(contractAddress, metadata);
    }

    function proposeEditWithMetadata(
        address contractAddress,
        string memory name,
        string memory symbol,
        string memory logoURI,
        uint8 decimals,
        MetadataInput[] calldata metadataUpdates
    ) external {
        // First propose the token edit
        ITokenEdits(tokenEdits).proposeEdit(contractAddress, name, symbol, logoURI, decimals);

        // Then propose the metadata edit
        ITokenMetadataEdits(metadataEdits).proposeMetadataEdit(contractAddress, metadataUpdates);
    }
}
