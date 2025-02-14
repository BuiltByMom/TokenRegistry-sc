#!/bin/bash

# Load environment variables
source .env.local

export PRIVATE_KEY
export INITIAL_OWNER
export RPC_URL

# Get chain ID
ROOT_CHAIN_ID=$(cast chain-id --rpc-url $RPC_URL)

TOKENTROLLER_ADDRESS=$(cat broadcast/TokenRegistry.s.sol/$ROOT_CHAIN_ID/run-latest.json | jq -r '[.transactions[] | select(.contractName=="TokentrollerV1") | .contractAddress][0]')

echo "Using contracts:"
echo "TOKENTROLLER_ADDRESS: $TOKENTROLLER_ADDRESS"

# Export addresses for the script
export TOKENTROLLER_ADDRESS

# Run the forge script
echo "Creating edits for approved tokens..."
forge script script/CreateEdits.s.sol:CreateEditsScript \
    --broadcast \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \

echo "Edit creation complete!"
