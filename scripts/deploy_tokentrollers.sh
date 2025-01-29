#!/bin/bash

# Load environment variables
source .env

echo "Deploying to root chain..."
forge script script/DeployHyperlaneRootPlugin.s.sol:DeployHyperlaneRootPlugin --broadcast --rpc-url http://localhost:8545

# Get the addresses and update .env
HYPERLANE_ROOT_PLUGIN=$(cat broadcast/DeployHyperlaneRootPlugin.s.sol/1000/run-latest.json | jq -r '.transactions[] | select(.contractName=="HyperlaneRootPlugin") | .contractAddress')
sed -i '' "s/^HYPERLANE_ROOT_PLUGIN=.*/HYPERLANE_ROOT_PLUGIN=$HYPERLANE_ROOT_PLUGIN/" .env

echo "Deploying to leaf chain..."
forge script script/DeployHyperlaneLeafPlugin.s.sol:DeployHyperlaneLeafPlugin --broadcast --rpc-url http://localhost:8546

HYPERLANE_LEAF_PLUGIN=$(cat broadcast/DeployHyperlaneLeafPlugin.s.sol/1001/run-latest.json | jq -r '.transactions[] | select(.contractName=="HyperlaneLeafPlugin") | .contractAddress')
sed -i '' "s/^HYPERLANE_LEAF_PLUGIN=.*/HYPERLANE_LEAF_PLUGIN=$HYPERLANE_LEAF_PLUGIN/" .env

echo "Setting leaf tokentroller in root..."
cast send --rpc-url http://localhost:8545 $HYPERLANE_ROOT_PLUGIN "setLeaf(uint256,address)" 1001 $HYPERLANE_LEAF_PLUGIN --private-key $PRIVATE_KEY