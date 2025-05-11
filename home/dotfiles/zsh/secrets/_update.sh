#!/usr/bin/env bash

# Determine the script's directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Set the paths relative to the script's directory
SECRETS_SH="$SCRIPT_DIR/secrets.sh"
SECRETS_AGE="$SCRIPT_DIR/secrets.age"

# Decrypt secrets.age if it exists
if [ -f "$SECRETS_AGE" ]; then
    if ! op read "op://Personal/master-ssh-key/private key" | age -d -i - "$SECRETS_AGE" > "$SECRETS_SH"; then
        echo "Error: Failed to decrypt $SECRETS_AGE"
        exit 1
    fi
fi

# Open the decrypted file in the default editor
$EDITOR "$SECRETS_SH"

# Encrypt the edited secrets.sh with GitHub keys and save as secrets.age
if ! op read "op://Personal/master-ssh-key/public key" | age -R - "$SECRETS_SH" > "$SECRETS_AGE"; then
    echo "Error: Failed to encrypt $SECRETS_SH"
    # Clean up even on failure if secrets.sh exists
    [ -f "$SECRETS_SH" ] && rm "$SECRETS_SH"
    exit 1
fi

echo "Successfully updated $SECRETS_AGE with contents from $SECRETS_SH"

# Remove the temporary decrypted file
rm "$SECRETS_SH"
