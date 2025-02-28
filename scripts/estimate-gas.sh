#!/bin/bash

# Load environment variables
source .env.local

export HYPERLANE_LEAF_PLUGIN
export HYPERLANE_LEAF_RPC
export PRIVATE_KEY

LEAF_CHAIN_ID=$(cast chain-id --rpc-url $HYPERLANE_LEAF_RPC)

# Deploy a test token if needed
forge script script/DeployTestToken.s.sol:DeployTestToken --broadcast --rpc-url $HYPERLANE_LEAF_RPC

# Get deployed test token address
TEST_TOKEN=$(cat broadcast/DeployTestToken.s.sol/$LEAF_CHAIN_ID/run-latest.json | jq -r '.transactions[] | select(.contractName=="TestTokenDeployment") | .contractAddress')

echo "Estimating gas for executeApproveToken..."
forge script script/GasEstimator.s.sol:GasEstimator \
    --sig "estimateExecuteApproveToken(address,address)" \
    $HYPERLANE_LEAF_PLUGIN \
    $TEST_TOKEN \
    --rpc-url $HYPERLANE_LEAF_RPC

echo "Estimating gas for executeRejectToken..."
forge script script/GasEstimator.s.sol:GasEstimator \
    --sig "estimateExecuteRejectToken(address,address,string)" \
    $HYPERLANE_LEAF_PLUGIN \
    $TEST_TOKEN \
    "This is a test reason" \
    --rpc-url $HYPERLANE_LEAF_RPC

echo "Estimating gas for executeAcceptTokenEdit..."
forge script script/GasEstimator.s.sol:GasEstimator \
    --sig "estimateExecuteAcceptTokenEdit(address,address,uint256)" \
    $HYPERLANE_LEAF_PLUGIN \
    $TEST_TOKEN \
    1 \
    --rpc-url $HYPERLANE_LEAF_RPC

echo "Estimating gas for executeRejectTokenEdit..."
forge script script/GasEstimator.s.sol:GasEstimator \
    --sig "estimateExecuteRejectTokenEdit(address,address,uint256,string)" \
    $HYPERLANE_LEAF_PLUGIN \
    $TEST_TOKEN \
    1 \
    "Edit rejection reason" \
    --rpc-url $HYPERLANE_LEAF_RPC

echo "Estimating gas for executeAddMetadataField..."
forge script script/GasEstimator.s.sol:GasEstimator \
    --sig "estimateExecuteAddMetadataField(address,string,bool)" \
    $HYPERLANE_LEAF_PLUGIN \
    "testField" \
    true \
    --rpc-url $HYPERLANE_LEAF_RPC

echo "Estimating gas for executeUpdateMetadataField..."
forge script script/GasEstimator.s.sol:GasEstimator \
    --sig "estimateExecuteUpdateMetadataField(address,string,bool,bool)" \
    $HYPERLANE_LEAF_PLUGIN \
    "logoURI" \
    false \
    true \
    --rpc-url $HYPERLANE_LEAF_RPC

echo "Estimating gas for executeUpdateRegistryTokentroller..."
forge script script/GasEstimator.s.sol:GasEstimator \
    --sig "estimateExecuteUpdateRegistryTokentroller(address,address)" \
    $HYPERLANE_LEAF_PLUGIN \
    "0x7D792EAfdD06aB176706ead14de32A988e20873c" \
    --rpc-url $HYPERLANE_LEAF_RPC

echo "Estimating gas for updateOwner..."
forge script script/GasEstimator.s.sol:GasEstimator \
    --sig "estimateUpdateOwner(address,address)" \
    $HYPERLANE_LEAF_PLUGIN \
    "0x7D792EAfdD06aB176706ead14de32A988e20873c" \
    --rpc-url $HYPERLANE_LEAF_RPC



echo "Estimating gas for updateTokenEdits..."
forge script script/GasEstimator.s.sol:GasEstimator \
    --sig "estimateUpdateTokenEdits(address,address)" \
    $HYPERLANE_LEAF_PLUGIN \
    "0x7D792EAfdD06aB176706ead14de32A988e20873c" \
    --rpc-url $HYPERLANE_LEAF_RPC


# Add buffer for safety (e.g., 20%)
# You can use this value as gasLimit in StandardHookMetadata