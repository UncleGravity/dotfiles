#!/usr/bin/env bash

# Set the paths
SECRETS_SH="secrets.sh"
SECRETS_AGE="secrets.age"

# Decrypt secrets.age if it exists
if [ -f "$SECRETS_AGE" ]; then
    if ! age -d -i ~/.ssh/id_ed25519 "$SECRETS_AGE" > "$SECRETS_SH"; then
        echo "Error: Failed to decrypt $SECRETS_AGE"
        exit 1
    fi
fi

# Open the decrypted file in the default editor
$EDITOR "$SECRETS_SH"

# Encrypt the edited secrets.sh with GitHub keys and save as secrets.age
if ! curl -s https://github.com/unclegravity.keys | age -R - "$SECRETS_SH" > "$SECRETS_AGE"; then
    echo "Error: Failed to encrypt $SECRETS_SH"
    exit 1
fi

echo "Successfully updated $SECRETS_AGE with contents from $SECRETS_SH"

# Remove the temporary decrypted file
rm "$SECRETS_SH"