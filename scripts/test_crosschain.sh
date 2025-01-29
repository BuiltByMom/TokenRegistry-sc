#!/bin/bash

# Load environment variables
source .env

forge script script/DeployTestToken.s.sol:DeployTestToken --broadcast --rpc-url http://localhost:8546

# Get deployed addresses
HYPERLANE_ROOT_PLUGIN=$(cat broadcast/DeployHyperlaneRootPlugin.s.sol/1000/run-latest.json | jq -r '.transactions[] | select(.contractName=="HyperlaneRootPlugin") | .contractAddress')
HYPERLANE_LEAF_PLUGIN=$(cat broadcast/DeployHyperlaneLeafPlugin.s.sol/1001/run-latest.json | jq -r '.transactions[] | select(.contractName=="HyperlaneLeafPlugin") | .contractAddress')
TEST_TOKEN=$(cat broadcast/DeployTestToken.s.sol/1001/run-latest.json | jq -r '.transactions[] | select(.contractName=="TestTokenDeployment") | .contractAddress')

# Get the token registry address from leaf tokentroller
TOKEN_REGISTRY=$(cast call --rpc-url http://localhost:8546 $HYPERLANE_LEAF_PLUGIN "tokenRegistry()" | tr -d '\n')
TOKEN_REGISTRY="0x${TOKEN_REGISTRY:26}"
echo "Token Registry: $TOKEN_REGISTRY"
echo "Test Token: $TEST_TOKEN"

# Check initial token status
echo "Initial token status..."
cast call --rpc-url http://localhost:8546 $TOKEN_REGISTRY "tokenStatus(address)" $TEST_TOKEN

echo "Approving token from root chain..."
cast send --rpc-url http://localhost:8545 $HYPERLANE_ROOT_PLUGIN "approveTokenOnLeaf(uint256,address)" 1001 $TEST_TOKEN --private-key $PRIVATE_KEY

# Wait a bit for the message to be processed
echo "Waiting for cross-chain message..."
sleep 10

# Check final token status
echo "Final token status..."
cast call --rpc-url http://localhost:8546 $TOKEN_REGISTRY "tokenStatus(address)" $TEST_TOKEN 