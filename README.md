# TokenRegistry

A decentralized token registry system built on Ethereum that allows for the registration, verification, and management of tokens across multiple chains.

## Overview

TokenRegistry is a smart contract system that provides:

- Token submission and verification
- Decentralized governance through a Tokentroller system
- Extensible token metadata management
- Community-driven token edit proposal system
- Optional multi-chain support through Hyperlane integration

## Architecture

The system consists of these core contracts:

#### TokenRegistry
> Core contract for managing token registrations and status
- Submit tokens for registration with metadata
- Approve or reject token submissions
- Track token status (pending/approved/rejected)
- Read functions to get token or multiple tokens info including ERC20 data
- Resubmit previously rejected tokens

#### TokenMetadata
> Handles extensible metadata fields and values for registered tokens
- Extensible metadata fields (add/update/deactivate)
- Required and optional metadata support
- Bulk metadata updates

#### TokenEdits
> Manages the proposal and approval of token metadata changes
- Community members can propose token metadata edits
- Multiple concurrent edit proposals per token
- Governance-controlled edit approval/rejection
- Automatic cleanup of competing proposals on acceptance

#### TokentrollerV1
> Base governance contract that controls access and permissions
- Flexible permission and access control system
- Upgradeable governance logic

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

### Basic Setup

First, set up your environment variables in `.env.local`:
```bash
# Required for deployment
PRIVATE_KEY=
INITIAL_OWNER=
RPC_URL=
```

### Deployment

The project includes several deployment scripts for different scenarios:

#### Basic Deployment
```bash
# Deploy the base system (TokenRegistry, TokenMetadata, TokenEdits, TokentrollerV1)
./scripts/deploy-registry.sh
```

#### Upload Tokens
```bash
# Upload tokens from tokens.json file
./scripts/upload-tokens.sh
```

### Register a Token

```solidity
// Submit a token for registration
MetadataInput[] memory metadata = new MetadataInput[](1);
metadata[0] = MetadataInput({
    field: "logoURI",
    value: "https://example.com/logo.png"
});
tokenRegistry.addToken(tokenAddress, metadata);
```

### Propose Token Edit

```solidity
// Propose an edit to an existing token
MetadataInput[] memory metadata = new MetadataInput[](2);
metadata[0] = MetadataInput({
    field: "logoURI",
    value: "https://example.com/new_logo.png"
});
metadata[1] = MetadataInput({
    field: "website",
    value: "https://example.com"
});
tokenEdits.proposeEdit(tokenAddress, metadata);
```

## Testing

```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/TokenRegistry.t.sol
```

## Optional Multi-chain Support

The TokenRegistry system can optionally be deployed across multiple chains using Hyperlane for cross-chain communication.

### Additional Contracts
- **HyperlaneRootPlugin**: Root contract for managing cross-chain token registry operations
- **HyperlaneLeafPlugin**: Leaf contract deployed on other chains for executing cross-chain commands

### Setup

1. Set additional environment variables in `.env.test`:
```bash
# Hyperlane Configuration
HYPERLANE_ROOT_RPC=
HYPERLANE_LEAF_RPC=
HYPERLANE_ROOT_MAILBOX=
HYPERLANE_LEAF_MAILBOX=
```

2. Deploy the Hyperlane contracts:
```bash
# Deploy root and leaf contracts
./scripts/deploy-tokentrollers.sh

# Optional: Deploy null ISM for testing (NOTE: ONLY FOR TESTING)
./scripts/deploy-null-ism.sh
```

### Cross-chain Operations

```solidity
// On root chain - approve token on leaf chain
HyperlaneRootPlugin(rootPlugin).approveTokenOnLeaf{value: msgValue}(
    destinationChainId,
    tokenAddress
);

// Get required message value
uint256 msgValue = HyperlaneRootPlugin(rootPlugin).quote(
    destinationChainId,
    message,
    Commands.APPROVE_TOKEN
);
```

### Features
- Cross-chain token registry synchronization
- Unified governance across chains
- Gasless operations on leaf chains
- Cross-chain message verification

### Security Considerations
- Cross-chain messages are verified through Hyperlane's security model
- Root chain maintains control over leaf chain operations
- Message delivery is guaranteed by Hyperlane's infrastructure
