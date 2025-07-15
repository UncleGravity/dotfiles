set shell := ["bash", "-c"]

# Determine the system type

system_type := `
    if [ -d /etc/nixos ]; then
        echo "nixos"
    elif command -v darwin-rebuild >/dev/null 2>&1; then
        echo "darwin"
    elif command -v home-manager >/dev/null 2>&1; then
        echo "home-manager"
    else
        echo "unknown"
    fi
`

# Rebuild the system configuration
sync: nixpkgs-status
    #!/usr/bin/env bash
    echo "🔄 Rebuilding system configuration for host: $(hostname) on platform: {{ system_type }}..."

    case "{{ system_type }}" in
        "nixos")
            HOSTNAME=$(hostname)
            if ! nh os switch . -H $HOSTNAME; then
                echo "❌ Failed to rebuild NixOS configuration."
                exit 1
            fi
            ;;
        "darwin")
            HOSTNAME=$(scutil --get ComputerName)
            if ! nh darwin switch . -H $HOSTNAME; then
                echo "❌ Failed to rebuild Darwin configuration."
                exit 1
            fi
            ;;
        "home-manager")
            USERNAME=$(whoami)
            if ! home-manager switch --flake .#$USERNAME; then
                echo "❌ Failed to rebuild Home Manager configuration."
                exit 1
            fi
            ;;
        *)
            echo "❌ Unsupported system type. Supported types are NixOS, Darwin, and Home Manager."
            exit 1
            ;;
    esac
    echo "✅ System configuration rebuilt successfully!"

# Create symlink for Neovim configuration
nvim:
    @echo "🔗 Creating symlink for Neovim configuration..."
    rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim
    ln -sfn $(pwd)/home/dotfiles/nvim "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim
    @echo "✅ Don't forget to delete the symlink when you're done."
    @echo "✅ Neovim configuration symlink created successfully!"

# Update flake inputs
update:
    @echo "🔄 Updating flake inputs..."
    nix flake update
    @echo "✅ Flake inputs updated successfully!"

# Update flake inputs and rebuild system configuration
update-sync: update sync
    @echo "🎉 System upgrade completed!"

# Garbage collect old generations (default: 30 days)
gc days="30d":
    @echo "🧹 Performing garbage collection..."
    nh clean all --keep-since {{ days }} --ask
    @echo "✅ Garbage collection completed!"

# Remove unused nix store paths
trim:
    @echo "✂️  Pruning unused nix store paths..."
    nix-store --gc
    @echo "✅ Pruning completed!"

# List system generations
list-generations:
    #!/usr/bin/env bash
    echo "📋 Listing system generations for {{ system_type }}..."
    case "{{ system_type }}" in
        "nixos")
            sudo nix-env -p /nix/var/nix/profiles/system --list-generations
            ;;
        "darwin")
            sudo darwin-rebuild --list-generations
            ;;
        "home-manager")
            nix-store --gc --print-roots | grep home-manager-generation
            ;;
        *)
            echo "❌ Error: Unsupported system type for listing generations."
            exit 1
            ;;
    esac

# Check system status
status:
    @echo "📊 System Status:"
    @echo "System Type: {{ system_type }}"
    @echo "Hostname: $(hostname)"
    @echo "Current User: $(whoami)"
    @echo "Nix Version: $(nix --version)"
    @echo "Flake Status:"
    @nix flake metadata

# Format and mount disk using Disko
[confirm("DANGER: This will destroy, format, and mount the disk according to the Disko configuration for the specified host. THIS IS A DESTRUCTIVE OPERATION. Are you sure you want to continue?")]
disko hostname:
    #!/usr/bin/env bash
    echo "💾 Preparing to format and mount disk using Disko for hostname: {{ hostname }}"
    if [ "{{ system_type }}" != "nixos" ]; then
        echo "❌ Disko command is only supported on NixOS systems."
        exit 1
    fi

    DISKO_CONFIG="./machines/{{ hostname }}/disko.nix"

    if [ ! -f "$DISKO_CONFIG" ]; then
        echo "❌ Disko configuration file not found: $DISKO_CONFIG"
        exit 1
    fi

    echo "🚀 Running Disko with config: $DISKO_CONFIG"
    if ! sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount "$DISKO_CONFIG"; then
        echo "❌ Failed to execute Disko command."
        exit 1
    fi
    echo "✅ Disko command completed successfully!"

# Synchronize remote NixOS machine
# Usage: just remote-sync <user> <hostname>
# Example: just remote-sync myuser myremoteserver
# remote-sync user host:
#     #!/usr/bin/env bash
#     set -euo pipefail
#     echo "🔄 Synchronizing remote NixOS machine: {{host}} as user {{user}}..."
#     # Note: The flake '.#{{host}}' assumes your flake has a NixOS configuration
#     # named after the target host (e.g., nixosConfigurations.myremoteserver).
#     echo "🚀 Executing nixos-rebuild for remote host '{{host}}'..."
#     if ! nix shell nixpkgs#nixos-rebuild --command nixos-rebuild switch \
#         --flake ".#{{host}}" \
#         --build-host "{{user}}@{{host}}" \
#         --target-host "{{user}}@{{host}}" \
#         --use-remote-sudo \
#         --fast; then
#         echo "❌ Failed to synchronize remote NixOS machine '{{host}}'."
#         exit 1
#     fi
#     echo "✅ Remote synchronization for '{{host}}' completed successfully!"
# [EXPERIMENTAL] Rsync entire flake directory and switch using nh
# Usage: just deploy <hostname>

# Example: just deploy myremoteserver
deploy host:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🧪 [EXPERIMENTAL] Synchronizing flake directory to remote host: {{ host }}..."

    REMOTE_PATH="/tmp/nix-flake-$(basename $(pwd))"

    echo "📁 Rsyncing flake directory to {{ host }}:$REMOTE_PATH..."
    if ! rsync -avz --delete --exclude='.git' --exclude='result*' . "{{ host }}:$REMOTE_PATH/"; then
        echo "❌ Failed to rsync flake directory to remote host."
        exit 1
    fi

    echo "🚀 Running 'nh os switch .' on remote host..."
    if ! ssh -t "{{ host }}" "cd $REMOTE_PATH && nix shell nixpkgs#nh --command nh os switch . --ask"; then
        echo "❌ Failed to run 'nh os switch .' on remote host."
        exit 1
    fi

    echo "✅ Experimental deployment for '{{ host }}' completed successfully!"
    echo "ℹ️  Remote flake directory is located at: {{ host }}:$REMOTE_PATH"

# Check nixpkgs version status
nixpkgs-status:
    #!/usr/bin/env bash
    LAST_MODIFIED=$(jq -r '.nodes.nixpkgs.locked.lastModified' flake.lock 2>/dev/null || echo "unknown")
    CURRENT_TIME=$(date +%s)
    DAYS_AGO=$(( (CURRENT_TIME - LAST_MODIFIED) / 86400 ))
    echo "📦 nixpkgs last updated: $DAYS_AGO days ago ($(date -d @$LAST_MODIFIED '+%Y-%m-%d %H:%M:%S'))"

# Display available commands
help:
    @just --list
    @echo "Run 'just <command>' to execute a command."
