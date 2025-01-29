// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@hyperlane-xyz/core/interfaces/IInterchainSecurityModule.sol";

contract NullIsm is IInterchainSecurityModule {
    uint8 public constant moduleType = uint8(Types.NULL);

    function verify(bytes calldata, bytes calldata) external pure returns (bool) {
        return true; // Accept all messages
    }
}
