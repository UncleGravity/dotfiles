#!/usr/bin/env bash
set -euo pipefail

# Create output directories
mkdir -p "$out/bin"
mkdir -p "$out/share/zsh/site-functions"

# Install cross-platform scripts
if [ -d all ]; then
  for script in all/*; do
    if [ -f "$script" ]; then
      install -Dm755 "$script" "$out/bin/$(basename "$script")"
    fi
  done
fi

# Install Darwin only scripts
if [ -d darwin ] && [[ "$system" == *"darwin"* ]]; then
  for script in darwin/*; do
    if [ -f "$script" ]; then
      install -Dm755 "$script" "$out/bin/$(basename "$script")"
    fi
  done
fi

# Install Linux only scripts
if [ -d linux ] && [[ "$system" == *"linux"* ]]; then
  for script in linux/*; do
    if [ -f "$script" ]; then
      install -Dm755 "$script" "$out/bin/$(basename "$script")"
    fi
  done
fi

# Install zsh completions
if [ -d _completions ]; then
  for completion in _completions/_*; do
    if [ -f "$completion" ]; then
      install -Dm644 "$completion" "$out/share/zsh/site-functions/$(basename "$completion")"
    fi
  done
fi

# Install backup configs
if [ -d backup ]; then
  mkdir -p "$out/share/scripts/backup"
  for file in backup/*; do
    if [ -f "$file" ]; then
      install -Dm644 "$file" "$out/share/scripts/backup/$(basename "$file")"
    fi
  done
fi 