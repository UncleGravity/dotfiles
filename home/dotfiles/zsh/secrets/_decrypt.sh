#!/usr/bin/env bash

SECRETS_DIR="$HOME/.config/zsh/secrets"
SECRETS_FILE="$SECRETS_DIR/secrets.age"
DECRYPTED_FILE="$SECRETS_DIR/secrets.sh"
# DEFAULT_KEY_FILE="$HOME/.ssh/id_ed25519"
# KEY_FILE=${AGE_KEY_FILE:-$DEFAULT_KEY_FILE}

decrypt_secrets() {
    # Check if op command exists
    if ! command -v op &> /dev/null; then
        echo "Error: 1Password CLI 'op' command not found. Please install it and ensure it's in your PATH." >&2
        return 1
    fi

    # Decrypt using op to fetch the key
    if ! op read "op://Personal/Master SSH Key/private key" | age -d -i - "$SECRETS_FILE" > "$DECRYPTED_FILE"; then
        echo "Error: Decryption failed. Check if 'op' is logged in and the secret path is correct." >&2
        # Clean up potentially partially written file
        rm -f "$DECRYPTED_FILE"
        return 1
    fi

    # Check if decryption produced a non-empty file
    if [ ! -s "$DECRYPTED_FILE" ]; then
        echo "Error: Decryption succeeded, but the resulting file is empty." >&2
        rm "$DECRYPTED_FILE"
        return 1
    fi
    chmod 600 "$DECRYPTED_FILE"
#        echo "Secrets decrypted successfully."
}

if [ ! -f "$DECRYPTED_FILE" ] || [ ! -s "$DECRYPTED_FILE" ]; then
    if [ -f "$SECRETS_FILE" ]; then
        decrypt_secrets || return 1
    else
        echo "Error: Encrypted secrets file not found at $SECRETS_FILE" >&2
        return 1
    fi
else
:   # echo "Decrypted secrets file already exists and is not empty."
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
