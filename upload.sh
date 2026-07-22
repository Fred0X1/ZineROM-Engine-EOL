#!/bin/bash

# Check if a file argument is provided
if [[ "$#" == '0' ]]; then
    echo 'ERROR: No File Specified!' && exit 1
fi

FILE="$1"

# Query GoFile API to find the best server for upload
SERVER=$(curl -s https://api.gofile.io/servers | jq -r '.data.servers[0].name')

if [ -z "$SERVER" ] || [ "$SERVER" == "null" ]; then
    echo "ERROR: Failed to fetch GoFile server!" && exit 1
fi

# Upload the file silently without progress hashes
LINK=$(curl -s --no-progress-meter -F "file=@$FILE" "https://${SERVER}.gofile.io/uploadFile" | jq -r '.data.downloadPage')

# Output final link
echo "$LINK"
