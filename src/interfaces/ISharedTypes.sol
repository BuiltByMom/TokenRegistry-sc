// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct MetadataInput {
    string field;
    string value;
}

struct MetadataValue {
    string field;
    string value;
    bool isActive;
}

enum TokenStatus {
    PENDING,
    APPROVED,
    REJECTED,
    NONE
}
