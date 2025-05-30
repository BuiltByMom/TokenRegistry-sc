// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Commands {
    uint256 public constant APPROVE_TOKEN = 0x00;
    uint256 public constant REJECT_TOKEN = 0x01;
    uint256 public constant ACCEPT_TOKEN_EDIT = 0x02;
    uint256 public constant REJECT_TOKEN_EDIT = 0x03;
    uint256 public constant ADD_METADATA_FIELD = 0x04;
    uint256 public constant UPDATE_METADATA_FIELD = 0x05;
    uint256 public constant UPDATE_REGISTRY_TOKENTROLLER = 0x06;
    uint256 public constant UPDATE_TOKEN_EDITS = 0x07;
    uint256 public constant UPDATE_OWNER = 0x08;

    // Default gas limits for each command + 20% buffer
    function defaultGasLimit(uint256 _command) public pure returns (uint256) {
        if (_command == Commands.APPROVE_TOKEN) return 202_082;
        if (_command == Commands.REJECT_TOKEN) return 209_404;
        if (_command == Commands.ACCEPT_TOKEN_EDIT) return 212_608;
        if (_command == Commands.REJECT_TOKEN_EDIT) return 97_251;
        if (_command == Commands.ADD_METADATA_FIELD) return 190_000;
        if (_command == Commands.UPDATE_METADATA_FIELD) return 113_000;
        if (_command == Commands.UPDATE_REGISTRY_TOKENTROLLER) return 130_000;
        if (_command == Commands.UPDATE_TOKEN_EDITS) return 93_000;
        if (_command == Commands.UPDATE_OWNER) return 93_000;
        return 0;
    }

    // Gas limit function that allows for custom override
    function gasLimit(uint256 _command, uint256 _customGasLimit) public pure returns (uint256) {
        return _customGasLimit > 0 ? _customGasLimit : defaultGasLimit(_command);
    }

    function gasLimit(uint256 _command) public pure returns (uint256) {
        return defaultGasLimit(_command);
    }
}
