#!/usr/bin/env bash

# Set the paths and keys
SECRETS_FILE="secrets.age"
TEMP_DECRYPTED="temp_decrypted.sh"
SSH_KEY="$HOME/.ssh/id_ed25519"

# Decrypt the secrets file
if ! age -d -i "$SSH_KEY" "$SECRETS_FILE" > "$TEMP_DECRYPTED"; then
    echo "Error: Failed to decrypt $SECRETS_FILE"
    exit 1
fi

# Re-encrypt with updated GitHub keys
if ! curl -s https://github.com/unclegravity.keys | age -R - "$TEMP_DECRYPTED" > "$SECRETS_FILE"; then
    echo "Error: Failed to re-encrypt secrets"
    rm "$TEMP_DECRYPTED"
    exit 1
fi

# Clean up
rm "$TEMP_DECRYPTED"

echo "Successfully updated $SECRETS_FILE with current GitHub SSH keys"