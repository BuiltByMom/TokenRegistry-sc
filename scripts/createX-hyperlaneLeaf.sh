#!/bin/bash

source .env.hyperlane

export PRIVATE_KEY
export INITIAL_OWNER
export HYPERLANE_LEAF_RPC
export HYPERLANE_ROOT_RPC
export TOKEN_METADATA
export TOKEN_REGISTRY
export TOKEN_EDITS
export HYPERLANE_LEAF_MAILBOX
export HYPERLANE_ROOT_PLUGIN

export LEAF_ETHERSCAN_API_KEY

echo "Deploying Hyperlane Leaf Plugin..."
forge script script/DeployHyperlaneLeafPlugin.s.sol:DeployHyperlaneLeafPlugin \
--rpc-url $HYPERLANE_LEAF_RPC \
--broadcast \
--sender $INITIAL_OWNER \
--verify \
--etherscan-api-key $LEAF_ETHERSCAN_API_KEY

LEAF_CHAIN_ID=$(cast chain-id --rpc-url $HYPERLANE_LEAF_RPC)

echo "Setting leaf tokentroller in root..."
cast send --rpc-url $HYPERLANE_ROOT_RPC $HYPERLANE_ROOT_PLUGIN "setLeaf(uint256,address)" $LEAF_CHAIN_ID $HYPERLANE_LEAF_PLUGIN --private-key $PRIVATE_KEY