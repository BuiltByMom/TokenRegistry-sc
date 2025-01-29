#!/bin/bash

# Load environment variables
source .env

forge script script/DeployTestToken.s.sol:DeployTestToken --broadcast --rpc-url http://localhost:8546

# Get deployed addresses
TOKENTROLLER_ROOT=$(cat broadcast/DeployTokentrollerRoot.s.sol/1000/run-latest.json | jq -r '.transactions[] | select(.contractName=="TokentrollerRoot") | .contractAddress')
TOKENTROLLER_LEAF=$(cat broadcast/DeployTokentrollerLeaf.s.sol/1001/run-latest.json | jq -r '.transactions[] | select(.contractName=="TokentrollerLeaf") | .contractAddress')
TEST_TOKEN=$(cat broadcast/DeployTestToken.s.sol/1001/run-latest.json | jq -r '.transactions[] | select(.contractName=="TestTokenDeployment") | .contractAddress')

# Get the token registry address from child tokentroller
TOKEN_REGISTRY=$(cast call --rpc-url http://localhost:8546 $TOKENTROLLER_LEAF "tokenRegistry()" | tr -d '\n')
TOKEN_REGISTRY="0x${TOKEN_REGISTRY:26}"
echo "Token Registry: $TOKEN_REGISTRY"
echo "Test Token: $TEST_TOKEN"

# Check initial token status
echo "Initial token status..."
cast call --rpc-url http://localhost:8546 $TOKEN_REGISTRY "tokenStatus(address)" $TEST_TOKEN

echo "Approving token from root chain..."
cast send --rpc-url http://localhost:8545 $TOKENTROLLER_ROOT "approveTokenOnLeaf(uint256,address)" 1001 $TEST_TOKEN --private-key $PRIVATE_KEY

# Wait a bit for the message to be processed
echo "Waiting for cross-chain message..."
sleep 10

# Check final token status
echo "Final token status..."
cast call --rpc-url http://localhost:8546 $TOKEN_REGISTRY "tokenStatus(address)" $TEST_TOKEN 