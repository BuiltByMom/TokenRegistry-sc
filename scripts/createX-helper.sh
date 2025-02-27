#!/bin/bash

source .env.local

export PRIVATE_KEY
export INITIAL_OWNER
export RPC_URL
export TOKENTROLLER_ADDRESS

echo "Deploying Helper..."
forge script script/DeployHelper.s.sol:DeployHelper \
--rpc-url $RPC_URL \
--broadcast \
--sender $INITIAL_OWNER
