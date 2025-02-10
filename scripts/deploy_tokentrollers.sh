#!/bin/bash

# Load environment variables
source .env.local

export PRIVATE_KEY
export HYPERLANE_LEAF_MAILBOX
export HYPERLANE_ROOT_MAILBOX
export HYPERLANE_ROOT_RPC
export HYPERLANE_LEAF_RPC

# Get chain IDs using cast
ROOT_CHAIN_ID=$(cast chain-id --rpc-url $HYPERLANE_ROOT_RPC)
LEAF_CHAIN_ID=$(cast chain-id --rpc-url $HYPERLANE_LEAF_RPC)

echo "Deploying to root chain..."
forge script script/DeployHyperlaneRootPlugin.s.sol:DeployHyperlaneRootPlugin --broadcast --rpc-url $HYPERLANE_ROOT_RPC

# Get the addresses and update .env
HYPERLANE_ROOT_PLUGIN=$(cat broadcast/DeployHyperlaneRootPlugin.s.sol/$ROOT_CHAIN_ID/run-latest.json | jq -r '.transactions[] | select(.contractName=="HyperlaneRootPlugin") | .contractAddress')
sed -i '' "s/^HYPERLANE_ROOT_PLUGIN=.*/HYPERLANE_ROOT_PLUGIN=$HYPERLANE_ROOT_PLUGIN/" .env.local

export HYPERLANE_ROOT_PLUGIN

echo "Deploying to leaf chain..."
forge script script/DeployHyperlaneLeafPlugin.s.sol:DeployHyperlaneLeafPlugin --broadcast --rpc-url $HYPERLANE_LEAF_RPC

HYPERLANE_LEAF_PLUGIN=$(cat broadcast/DeployHyperlaneLeafPlugin.s.sol/$LEAF_CHAIN_ID/run-latest.json | jq -r '.transactions[] | select(.contractName=="HyperlaneLeafPlugin") | .contractAddress')
sed -i '' "s/^HYPERLANE_LEAF_PLUGIN=.*/HYPERLANE_LEAF_PLUGIN=$HYPERLANE_LEAF_PLUGIN/" .env.local

echo "Setting leaf tokentroller in root..."
cast send --rpc-url $HYPERLANE_ROOT_RPC $HYPERLANE_ROOT_PLUGIN "setLeaf(uint256,address)" $LEAF_CHAIN_ID $HYPERLANE_LEAF_PLUGIN --private-key $PRIVATE_KEY