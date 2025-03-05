// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TokentrollerBase.sol";

contract TokentrollerV1 is TokentrollerBase {
    constructor(address _owner) TokentrollerBase(_owner) {
        tokenMetadata = address(new TokenMetadata(address(this)));
        tokenRegistry = address(new TokenRegistry(address(this), tokenMetadata));
        tokenEdits = address(new TokenEdits(address(this), tokenMetadata));
    }
}
