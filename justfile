set shell := ["bash", "-euo", "pipefail", "-c"]

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

# Default: list available commands
default:
    @just sync

# Rebuild the system configuration
sync: nixpkgs-status
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Rebuilding system configuration for host: $(hostname) on platform: {{ system_type }}..."

    case "{{ system_type }}" in
        "nixos")
            HOSTNAME=$(hostname)
            nh os switch . -H $HOSTNAME
            ;;
        "darwin")
            HOSTNAME=$(scutil --get ComputerName)

            # Check if Rosetta 2 is available
            if ! arch -x86_64 /bin/bash -c 'exit 0' 2>/dev/null; then
                echo "WARNING: Rosetta 2 not available. Intel packages may fail."
                echo ""
            fi

            nh darwin switch . -H $HOSTNAME
            ;;
        "home-manager")
            USERNAME=$(whoami)
            home-manager switch --flake .#$USERNAME
            ;;
        *)
            echo "❌ Unsupported system type. Supported types are NixOS, Darwin, and Home Manager."
            exit 1
            ;;
    esac
    echo "System configuration rebuilt successfully!"

# Update flake inputs
update:
    @echo "Updating flake inputs..."
    nix flake update
    @echo "Flake inputs updated successfully!"

# Update flake inputs and rebuild system configuration
update-sync: update sync
    @echo "System upgrade completed!"

# Garbage collect old generations (default: 30 days)
gc days="30d":
    @echo "🧹 Performing garbage collection..."
    nh clean all --keep-since {{ days }} --ask
    @echo "Garbage collection completed!"

# Remove unused nix store paths
trim:
    @echo "Pruning unused nix store paths..."
    nix-store --gc
    @echo "✅ Pruning completed!"

# List system generations
list-generations:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Listing system generations for {{ system_type }}..."
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
    set -euo pipefail
    echo "Preparing to format and mount disk using Disko for hostname: {{ hostname }}"
    if [ "{{ system_type }}" != "nixos" ]; then
        echo "❌ Disko command is only supported on NixOS systems."
        exit 1
    fi

    DISKO_CONFIG="./machines/{{ hostname }}/disko.nix"

    if [ ! -f "$DISKO_CONFIG" ]; then
        echo "❌ Disko configuration file not found: $DISKO_CONFIG"
        exit 1
    fi

    echo "Running Disko with config: $DISKO_CONFIG"
    sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount "$DISKO_CONFIG"
    echo "Disko command completed successfully!"

# Deploy a NixOS host over SSH using nh remote build/deploy.
# Usage: just deploy <hostname>
# Example: just deploy kiwi
deploy host:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Deploying NixOS configuration to {{ host }}..."
    nh os switch . -H "{{ host }}" --build-host "{{ host }}" --target-host "{{ host }}" --ask
    echo "Deployment for '{{ host }}' completed successfully!"

# Check nixpkgs version status
nixpkgs-status:
    #!/usr/bin/env bash
    set -euo pipefail
    LAST_MODIFIED=$(jq -r '.nodes.nixpkgs.locked.lastModified' flake.lock 2>/dev/null || echo "unknown")
    CURRENT_TIME=$(date +%s)
    DAYS_AGO=$(( (CURRENT_TIME - LAST_MODIFIED) / 86400 ))
    # BSD date (macOS) uses -r; GNU date uses -d @
    if date -r 0 +%s >/dev/null 2>&1; then
        HUMAN=$(date -r "$LAST_MODIFIED" '+%Y-%m-%d %H:%M:%S')
    else
        HUMAN=$(date -d "@$LAST_MODIFIED" '+%Y-%m-%d %H:%M:%S')
    fi
    echo "📦 nixpkgs last updated: $DAYS_AGO days ago ($HUMAN)"

# Profile nix evaluation performance (optionally specify a hostname)
profile host="":
    @./scripts/nix-profile.sh {{ host }}

# Display available commands
help:
    @just --list
    @echo "Run 'just <command>' to execute a command."
