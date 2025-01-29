#!/bin/bash

# Load environment variables
source .env

TOKENTROLLER_ROOT=$(cat broadcast/DeployTokentrollerRoot.s.sol/1000/run-latest.json | jq -r '.transactions[] | select(.contractName=="TokentrollerRoot") | .contractAddress')
TOKENTROLLER_LEAF=$(cat broadcast/DeployTokentrollerLeaf.s.sol/1001/run-latest.json | jq -r '.transactions[] | select(.contractName=="TokentrollerLeaf") | .contractAddress')
TEST_TOKEN=$(cat broadcast/DeployAll.s.sol/1001/run-latest.json | jq -r '.transactions[] | select(.contractName=="TestTokenDeployment") | .contractAddress')

# # Get message details from the parent chain
# echo "Getting message details..."

# # Create the message body (the function call we want to execute)
# MESSAGE_BODY=$(cast calldata "executeApproveToken(address)" $TEST_TOKEN)

# # Create a temporary Solidity file to use the Message library
# cat > /tmp/MessageFormatter.sol << EOL
# // SPDX-License-Identifier: MIT
# pragma solidity ^0.8.0;

# contract MessageFormatter {
#     function formatMessage(
#         uint8 _version,
#         uint32 _nonce,
#         uint32 _originDomain,
#         bytes32 _sender,
#         uint32 _destinationDomain,
#         bytes32 _recipient,
#         bytes calldata _messageBody
#     ) external pure returns (bytes memory) {
#         return abi.encodePacked(
#             _version,
#             _nonce,
#             _originDomain,
#             _sender,
#             _destinationDomain,
#             _recipient,
#             _messageBody
#         );
#     }
# }
# EOL

# # Compile the temporary contract
# forge build

# # Create the message using the Message library's formatMessage
# MESSAGE=$(cast call --rpc-url http://localhost:8546 $(forge create --rpc-url http://localhost:8546 --private-key $PRIVATE_KEY /tmp/MessageFormatter.sol:MessageFormatter | grep "Deployed to" | cut -d' ' -f3) "formatMessage(uint8,uint32,uint32,bytes32,uint32,bytes32,bytes)" 3 7 1000 $(cast --to-bytes32 $PARENT_TOKENTROLLER) 1001 $(cast --to-bytes32 $CHILD_TOKENTROLLER) $MESSAGE_BODY)

# echo "Message: $MESSAGE"

MESSAGE=0x0300000007000003e80000000000000000000000001f4fc3074ce3da47ea5bda7c7cca776eb5f4296f000003e90000000000000000000000009f20851fb51479ae615dae2cea91ff467d58d468297d8157000000000000000000000000cc2da9140eb058f81e967a673ed8f91ba1700c8d000000000000000000000000000000

# Try call first to get more error details
echo "Trying call first to debug..."
cast call --rpc-url http://localhost:8546 $LEAF_MAILBOX "process(bytes,bytes)" "0x" $MESSAGE

# Try with trace to see where it reverts
echo "Trying with trace..."
cast call --rpc-url http://localhost:8546 $LEAF_MAILBOX "process(bytes,bytes)" "0x" $MESSAGE --trace

# If we still want to send it
echo "Processing message..."
cast send --rpc-url http://localhost:8546 $LEAF_MAILBOX "process(bytes,bytes)" "0x" $MESSAGE --private-key $PRIVATE_KEY 