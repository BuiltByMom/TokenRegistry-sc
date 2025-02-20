#!/bin/bash

source .env.test

export PRIVATE_KEY
export INITIAL_OWNER
export RPC_URL
export TOKENTROLLER_ADDRESS
export TOKEN_METADATA_ADDRESS
export ETHERSCAN_API_KEY

echo "Deploying Token Edits..."
forge script script/DeployTokenEdits.s.sol:DeployTokenEdits \
--rpc-url $RPC_URL \
--broadcast \
--sender $INITIAL_OWNER \
--verify \
--etherscan-api-key $ETHERSCAN_API_KEY
