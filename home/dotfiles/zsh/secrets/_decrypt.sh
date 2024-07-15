#!/usr/bin/env bash

SECRETS_DIR="$HOME/.config/zsh/secrets"
SECRETS_FILE="$SECRETS_DIR/secrets.age"
DECRYPTED_FILE="$SECRETS_DIR/secrets.sh"
# DEFAULT_KEY_FILE="$HOME/.age/key.txt"
DEFAULT_KEY_FILE="$HOME/.ssh/id_ed25519"
KEY_FILE=${AGE_KEY_FILE:-$DEFAULT_KEY_FILE}

decrypt_secrets() {
    if [ -f "$KEY_FILE" ]; then
        age -d -i "$KEY_FILE" "$SECRETS_FILE" > "$DECRYPTED_FILE"
        if [ ! -s "$DECRYPTED_FILE" ]; then
            echo "Error: Decryption failed. The decrypted file is empty." >&2
            rm "$DECRYPTED_FILE"
            return 1
        fi
        chmod 600 "$DECRYPTED_FILE"
#        echo "Secrets decrypted successfully."
    else
        echo "Error: Age key file not found at $KEY_FILE" >&2
        return 1
    fi
}

if [ ! -f "$DECRYPTED_FILE" ] || [ ! -s "$DECRYPTED_FILE" ]; then
    if [ -f "$SECRETS_FILE" ]; then
        decrypt_secrets || return 1
    else
        echo "Error: Encrypted secrets file not found at $SECRETS_FILE" >&2
        return 1
    fi
else
#    echo "Decrypted secrets file already exists and is not empty."
fi

# Source the decrypted secrets file
if [ -f "$DECRYPTED_FILE" ] && [ -s "$DECRYPTED_FILE" ]; then
#    echo "Sourcing $DECRYPTED_FILE"
    source "$DECRYPTED_FILE"
else
    echo "Warning: $DECRYPTED_FILE not found or is empty. Some environment variables may not be set." >&2
    # [ -f "$DECRYPTED_FILE" ] && rm "$DECRYPTED_FILE"
    return 1
fi