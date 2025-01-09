#!/bin/bash

# Check if .env exists
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    exit 1
fi

# Load environment variables
source .env

# Run the forge script
echo "Uploading tokens to registry at $TOKEN_REGISTRY_ADDRESS..."
forge script script/UploadTokens.s.sol:UploadTokensScript \
    --broadcast \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --gas-limit 3000000000 \

echo "Upload complete!" 