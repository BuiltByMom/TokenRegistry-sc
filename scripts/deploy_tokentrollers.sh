#!/bin/bash

# Load environment variables
source .env

echo "Deploying to root chain..."
forge script script/DeployTokentrollerRoot.s.sol:DeployTokentrollerRoot --broadcast --rpc-url http://localhost:8545

# Get the addresses and update .env
TOKENTROLLER_ROOT=$(cat broadcast/DeployTokentrollerRoot.s.sol/1000/run-latest.json | jq -r '.transactions[] | select(.contractName=="TokentrollerRoot") | .contractAddress')
sed -i '' "s/^TOKENTROLLER_ROOT=.*/TOKENTROLLER_ROOT=$TOKENTROLLER_ROOT/" .env

echo "Deploying to leaf chain..."
forge script script/DeployTokentrollerLeaf.s.sol:DeployTokentrollerLeaf --broadcast --rpc-url http://localhost:8546

TOKENTROLLER_LEAF=$(cat broadcast/DeployTokentrollerLeaf.s.sol/1001/run-latest.json | jq -r '.transactions[] | select(.contractName=="TokentrollerLeaf") | .contractAddress')
sed -i '' "s/^TOKENTROLLER_LEAF=.*/TOKENTROLLER_LEAF=$TOKENTROLLER_LEAF/" .env

echo "Setting leaf tokentroller in root..."
cast send --rpc-url http://localhost:8545 $TOKENTROLLER_ROOT "setTokentrollerLeaf(uint256,address)" 1001 $TOKENTROLLER_LEAF --private-key $PRIVATE_KEY
