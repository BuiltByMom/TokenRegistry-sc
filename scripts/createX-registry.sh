#!/bin/bash

source .env.local

export PRIVATE_KEY
export INITIAL_OWNER
export RPC_URL

# Deploy token registry
echo "Deploying Token Registry..."
forge script script/DeployTokenRegistry.s.sol:DeployTokenRegistry \
--rpc-url $RPC_URL \
--broadcast \
--sender $INITIAL_OWNER
