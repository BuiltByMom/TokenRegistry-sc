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

> Note: make sure you have a valid TOKEN_REGISTRY_ADDRESS, TOKENTROLLER_ADDRESS, RPC_URL, PRIVATE_KEY, and INITIAL_OWNER in your .env file
```
PRIVATE_KEY=
INITIAL_OWNER=
TOKEN_REGISTRY_ADDRESS=
TOKENTROLLER_ADDRESS=
RPC_URL=
```

```bash
# Deploy using script
forge script script/TokenRegistry.s.sol:DeployTokenRegistry \
--rpc-url <your_rpc_url> \
--private-key <your_private_key> \
--broadcast
```

OR to deploy to anvil with preexisting multicall contract

```bash
./scripts/deploy-anvil.sh
```

You can also upload some tokens into the registry from tokens.json file

```bash
./scripts/upload-tokens.sh
```

### Register a Token

```solidity
// Submit a token for registration
tokenRegistry.addToken(
    tokenAddress,
    "Token Name",
    "TKN",
    "ipfs://QmREhgt4Q1xEWMqM1RAB85UpXai6ekWrj33cYrV7qCoaWP",
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
    "ipfs://QmREhgt4Q1xEWMqM1RAB85UpXai6ekWrj33cYrV7qCoaWP",
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
