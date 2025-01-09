#!/bin/bash

# Default values
BATCH_SIZE=50
START_INDEX=0
CONTINUE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --batch-size)
      BATCH_SIZE="$2"
      shift 2
      ;;
    --start-index)
      START_INDEX="$2"
      shift 2
      ;;
    --continue)
      CONTINUE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Load environment variables
source .env

# Function to extract next index from forge output
get_next_index() {
    local forge_output="$1"
    local next_index=$(echo "$forge_output" | grep "To process next batch, run with --start-index" | grep -o '[0-9]*$')
    echo "$next_index"
}

# Process batches until complete
while true; do
    echo "Processing batch starting at index $START_INDEX"
    
    # Run the forge script and capture output
    OUTPUT=$(forge script script/UploadTokensBatch.s.sol:UploadTokensBatchScript \
        --sig "run(uint256,uint256)" $START_INDEX $BATCH_SIZE \
        --broadcast \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY 2>&1)
    
    echo "$OUTPUT"

    # Check if all tokens are processed
    if echo "$OUTPUT" | grep -q "All tokens processed!"; then
        echo "Deployment complete!"
        break
    fi

    # Get next index
    NEXT_INDEX=$(get_next_index "$OUTPUT")
    if [ -z "$NEXT_INDEX" ]; then
        echo "Failed to get next index. Stopping."
        exit 1
    fi

    START_INDEX=$NEXT_INDEX
    
    # Optional: Add delay between batches
    sleep 2
done 