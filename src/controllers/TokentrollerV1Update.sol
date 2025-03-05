// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TokentrollerBase.sol";

contract TokentrollerV1Update is TokentrollerBase {
    constructor(
        address _owner,
        address _tokenMetadata,
        address _tokenRegistry,
        address _tokenEdits
    ) TokentrollerBase(_owner) {
        tokenMetadata = _tokenMetadata;
        tokenRegistry = _tokenRegistry;
        tokenEdits = _tokenEdits;
    }
}
