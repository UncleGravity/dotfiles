#!/usr/bin/env bash

# Create directory if it doesn't exist
mkdir -p "$HOME/.config/sops/age"

# Generate age keypair
age-keygen -o "$HOME/.config/sops/age/keys.txt"

# Set permissions to 600 (user read/write only)
chmod 600 "$HOME/.config/sops/age/keys.txt"

# Output the keys
cat "$HOME/.config/sops/age/keys.txt"
