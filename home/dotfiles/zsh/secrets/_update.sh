#!/usr/bin/env bash

# Set the paths
SECRETS_SH="secrets.sh"
SECRETS_AGE="secrets.age"

# Check if secrets.sh exists
if [ ! -f "$SECRETS_SH" ]; then
    echo "Error: $SECRETS_SH does not exist"
    exit 1
fi

# Encrypt secrets.sh with GitHub keys and save as secrets.age
if ! curl -s https://github.com/unclegravity.keys | age -R - "$SECRETS_SH" > "$SECRETS_AGE"; then
    echo "Error: Failed to encrypt $SECRETS_SH"
    exit 1
fi

echo "Successfully updated $SECRETS_AGE with contents from $SECRETS_SH"