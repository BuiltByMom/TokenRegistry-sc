# TokenRegistry

A decentralized token registry system built on Ethereum that allows for the registration, verification, and management of tokens across multiple chains.

## Overview

TokenRegistry is a smart contract system that provides:

- Token submission and verification
- Multi-chain token management 
- Decentralized governance through a Tokentroller
- Token metadata management
- Edit proposal and approval system

## Architecture

The system consists of three main contracts:

- **TokenRegistry**: Core contract for managing token registrations and edits
- **TokenMetadataRegistry**: Handles additional metadata for registered tokens
- **TokentrollerV1**: Governance contract that controls access and permissions

## Features

- Submit tokens for registration
- Manage token approvals
- Propose and approve token edits
- Manage token metadata
- Multi-chain support
- Permissioned governance

## Installation

```bash
# Clone the repository
git clone https://github.com/builtbymom/TokenRegistry.git

# Install dependencies
forge install

# Build
forge build

# Run tests
forge test
```

## Usage

### Deploy Contracts

```bash
# Deploy using script
forge script script/TokenRegistry.s.sol:DeployTokenRegistry \
--rpc-url <your_rpc_url> \
--private-key <your_private_key> \
--broadcast
```

OR to deploy to anvil with preexisting multicall contract

```bash
./deploy.sh
```

### Register a Token

```solidity
// Submit a token for registration
tokenRegistry.addToken(
    tokenAddress,
    "Token Name",
    "TKN",
    "https://token-logo.png",
    18,
    chainID
);
```

### Propose Token Edit

```solidity
// Propose an edit to an existing token
tokenRegistry.proposeTokenEdit(
    tokenAddress,
    "New Token Name",
    "NTKN",
    "https://new-token-logo.png",
    18,
    chainID
);
```

## Testing

The project includes a comprehensive test suite:

```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -vvv
```
