#!/bin/bash
source .env.local

# Deploy NULL ISM to both chains
echo "Deploying NULL ISM to chain 1..."
NULL_ISM_1=$(forge create --rpc-url http://localhost:8545 src/bridge/NullIsm.sol:NullIsm --private-key $PRIVATE_KEY --json --broadcast | jq -r .deployedTo)
echo "NULL ISM deployed at: $NULL_ISM_1"

echo "Deploying NULL ISM to chain 2..."
NULL_ISM_2=$(forge create --rpc-url http://localhost:8546 src/bridge/NullIsm.sol:NullIsm --private-key $PRIVATE_KEY --json --broadcast | jq -r .deployedTo)
echo "NULL ISM deployed at: $NULL_ISM_2"

# Set default ISM in Mailbox on both chains
echo "Setting default ISM in Mailbox on chain 1..."
cast send --rpc-url http://localhost:8545 $HYPERLANE_ROOT_MAILBOX "setDefaultIsm(address)" $NULL_ISM_1 --private-key $PRIVATE_KEY

echo "Setting default ISM in Mailbox on chain 2..."
cast send --rpc-url http://localhost:8546 $HYPERLANE_LEAF_MAILBOX "setDefaultIsm(address)" $NULL_ISM_2 --private-key $PRIVATE_KEY

echo "Done!"