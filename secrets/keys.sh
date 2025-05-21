#!/usr/bin/env bash

set -e # Exit immediately if a command exits with a non-zero status.

# Log all output to a file. For troubleshooting ONLY.
LOG_FILE="/tmp/keys_sh.log"
exec > >(tee -a "${LOG_FILE}") 2> >(tee -a "${LOG_FILE}" >&2)

if [[ "$(uname)" == "Darwin" ]]; then
  # Print the currently logged in console user
  CONSOLE_USER=$(/usr/bin/stat -f%Su /dev/console)
  su - $CONSOLE_USER -c 'op item get "master-ssh-key" --field "private key" --reveal | ssh-to-age -private-key'
elif [[ "$(uname)" == "Linux" ]]; then
  cat ~/.ssh/id_ed25519 | ssh-to-age -private-key
else
  echo "Unsupported OS"
  exit 1
fi