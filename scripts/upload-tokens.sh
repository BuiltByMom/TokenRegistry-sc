#!/bin/bash

source .env.local

export PRIVATE_KEY
export INITIAL_OWNER
export RPC_URL

ROOT_CHAIN_ID=$(cast chain-id --rpc-url $RPC_URL)

TOKENTROLLER_ADDRESS=$(cat broadcast/TokenRegistry.s.sol/$ROOT_CHAIN_ID/run-latest.json | jq -r '.transactions[] | select(.contractName=="TokentrollerV1") | .contractAddress')

echo "TOKENTROLLER_ADDRESS: $TOKENTROLLER_ADDRESS"

export TOKENTROLLER_ADDRESS

# Run the forge script
echo "Uploading tokens to registry at $TOKEN_REGISTRY_ADDRESS..."
forge script script/UploadTokens.s.sol:UploadTokensScript \
    --broadcast \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --gas-limit 3000000000 \

echo "Upload complete!" 