#!/bin/bash

ACTION=$1
BASE_PATH=$2

if [[ "$ACTION" == "discover" ]]; then
  # Discover subdirectories in the given path
  find "$BASE_PATH" -mindepth 1 -maxdepth 1 -type d | awk -F/ '{print "{\"{#SUBDIR}\":\"" $NF "\"}"}' | jq -s '{data: .}'

elif [[ "$ACTION" == "size" ]]; then
  # Calculate the size of the given subdirectory
  DIR="$BASE_PATH"
  if [ -d "$DIR" ]; then
    # Get size in kilobytes, suppress errors, and convert to bytes
    du -sk "$DIR" 2>/dev/null | awk '{print $1 * 1024}'
  else
    # If directory does not exist or is inaccessible, return 0
    echo "0"
  fi

else
  echo "Invalid action"
  exit 1
fi