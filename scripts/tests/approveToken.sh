#!/bin/bash

# Load environment variables
source .env.local

ROOT_CHAIN_ID=$(cast chain-id --rpc-url $HYPERLANE_ROOT_RPC)
LEAF_CHAIN_ID=$(cast chain-id --rpc-url $HYPERLANE_LEAF_RPC)

HYPERLANE_ROOT_PLUGIN=$(cat broadcast/DeployHyperlaneRootPlugin.s.sol/$ROOT_CHAIN_ID/run-latest.json | jq -r '.transactions[] | select(.contractName=="HyperlaneRootPlugin") | .contractAddress')
HYPERLANE_LEAF_PLUGIN=$(cat broadcast/DeployHyperlaneLeafPlugin.s.sol/$LEAF_CHAIN_ID/run-latest.json | jq -r '.transactions[] | select(.contractName=="HyperlaneLeafPlugin") | .contractAddress')

export HYPERLANE_ROOT_PLUGIN
export HYPERLANE_LEAF_PLUGIN
export PRIVATE_KEY

forge script script/DeployTestToken.s.sol:DeployTestToken --broadcast --rpc-url $HYPERLANE_LEAF_RPC

# Get deployed addresses
TEST_TOKEN=$(cat broadcast/DeployTestToken.s.sol/$LEAF_CHAIN_ID/run-latest.json | jq -r '.transactions[] | select(.contractName=="TestTokenDeployment") | .contractAddress')

# Get the token registry address from leaf tokentroller
TOKEN_REGISTRY=$(cast call --rpc-url $HYPERLANE_LEAF_RPC $HYPERLANE_LEAF_PLUGIN "tokenRegistry()" | tr -d '\n')
TOKEN_REGISTRY="0x${TOKEN_REGISTRY:26}"
echo "Token Registry: $TOKEN_REGISTRY"
echo "Test Token: $TEST_TOKEN"

# Check initial token status
echo "Initial token status..."
cast call --rpc-url $HYPERLANE_LEAF_RPC $TOKEN_REGISTRY "tokenStatus(address)" $TEST_TOKEN

# Manually create the message bytes
# 1. Get the function signature and remove the 0x prefix
FUNC_SIG=$(cast sig "executeApproveToken(address)")
FUNC_SIG=${FUNC_SIG#0x}

# 2. Pad the address and remove the 0x prefix
PADDED_ADDRESS=$(cast --to-uint256 $TEST_TOKEN)
PADDED_ADDRESS=${PADDED_ADDRESS#0x}

# 3. Combine them with a single 0x prefix
MESSAGE="0x${FUNC_SIG}${PADDED_ADDRESS}"
echo "Message bytes: $MESSAGE"

# Debug output
echo "Function signature: ${FUNC_SIG}"
echo "Padded address: ${PADDED_ADDRESS}"
echo "Final message: ${MESSAGE}"

# Get quote for cross-chain message
QUOTE=$(cast call --rpc-url $HYPERLANE_ROOT_RPC $HYPERLANE_ROOT_PLUGIN "quote(uint256,bytes,uint256)" $LEAF_CHAIN_ID $MESSAGE 0)
QUOTE_DEC=$(cast --to-dec $QUOTE)
echo "Quote for cross-chain message: $QUOTE_DEC"

echo "Approving token from root chain..."
cast send --rpc-url $HYPERLANE_ROOT_RPC $HYPERLANE_ROOT_PLUGIN "approveTokenOnLeaf(uint256,address)" $LEAF_CHAIN_ID $TEST_TOKEN --value $QUOTE_DEC --private-key $PRIVATE_KEY

# Wait a bit for the message to be processed
echo "Waiting for cross-chain message..."
sleep 30

# Check final token status
echo "Final token status..."
cast call --rpc-url $HYPERLANE_LEAF_RPC $TOKEN_REGISTRY "tokenStatus(address)" $TEST_TOKEN
