#!/bin/bash

source .env.hyperlane

export PRIVATE_KEY
export INITIAL_OWNER
export RPC_URL
export TOKEN_METADATA
export TOKEN_REGISTRY
export TOKEN_EDITS
export HYPERLANE_ROOT_MAILBOX

export ETHERSCAN_API_KEY

echo "Deploying Hyperlane Root Plugin..."
forge script script/DeployHyperlaneRootPlugin.s.sol:DeployHyperlaneRootPlugin \
--rpc-url $RPC_URL \
--broadcast \
--sender $INITIAL_OWNER \
--verify \
--etherscan-api-key $ETHERSCAN_API_KEY

