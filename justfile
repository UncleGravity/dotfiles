set shell := ["bash", "-euo", "pipefail", "-c"]

# Determine the system type

system_type := `
    if [ -e /etc/NIXOS ] || [ -d /etc/nixos ]; then
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
    @just --list

# Rebuild the system configuration
sync: nixpkgs-status
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Rebuilding system configuration for host: $(hostname) on platform: {{ system_type }}..."

    case "{{ system_type }}" in
        "nixos")
            HOSTNAME=$(hostname -s)
            nh os switch . -H "$HOSTNAME"
            ;;
        "darwin")
            HOSTNAME=$(scutil --get LocalHostName 2>/dev/null || hostname -s)

            # Check if Rosetta 2 is available
            if ! arch -x86_64 /bin/bash -c 'exit 0' 2>/dev/null; then
                echo "WARNING: Rosetta 2 not available. Intel packages may fail."
                echo ""
            fi

            nh darwin switch . -H "$HOSTNAME"
            ;;
        "home-manager")
            USERNAME=$(whoami)
            nh home switch . -c "$USERNAME"
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

# Format repository files
fmt:
    nix fmt .

# Validate the flake
check:
    nix flake check

# Lint Nix files
lint:
    statix check .

# Garbage collect old generations (default: 30 days)
gc days="30d":
    @echo "Performing garbage collection..."
    nh clean all --keep-since "{{ days }}" --ask
    @echo "Garbage collection completed!"

# Remove unused nix store paths
trim:
    @echo "Pruning unused nix store paths..."
    nix-store --gc
    @echo "Pruning completed!"

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
            nix-store --gc --print-roots | grep home-manager-generation || true
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

    DISKO_CONFIG="./machines/nixos/{{ hostname }}/hardware/disko.nix"

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

# Partition the NVMe, install NixOS, preserve host keys, and reboot.
# The node must be booted into the NixOS USB installer first (see spark README).
spark-install node:
    nix develop -c ./machines/nixos/spark/install.sh "{{ node }}"

# Deploy one Spark (builds on the node itself).
spark-deploy node:
    nh os switch . -H "{{ node }}" --build-host "{{ node }}.local" --target-host "{{ node }}.local"

# Deploy all four Sparks in canary order (stops on first failure).
spark-deploy-all:
    #!/usr/bin/env bash
    set -euo pipefail
    for node in spark-01 spark-02 spark-03 spark-04; do
        just spark-deploy "$node"
    done

# Push the expensive Spark build outputs (NVIDIA kernel + drivers, open-webui
# with its overridden torch stack) from a built node to cachix so installs and
# deploys elsewhere just download them. Extend the attr list as new
# built-from-source packages appear.
spark-cache node="spark-01":
    #!/usr/bin/env bash
    set -euo pipefail
    attrs=(
        boot.kernelPackages.kernel
        boot.kernelPackages.kernel.dev
        hardware.nvidia.package.open
        hardware.nvidia.package.firmware
        services.open-webui.package
    )
    paths=()
    for attr in "${attrs[@]}"; do
        paths+=("$(nix eval --raw ".#nixosConfigurations.{{ node }}.config.$attr.outPath")")
    done
    echo "Pushing: ${paths[*]}"
    nix copy --from "ssh://angel@{{ node }}.local" --no-check-sigs "${paths[@]}"
    nix develop -c cachix push unclegravity-nix "${paths[@]}"

# Check nixpkgs version status
nixpkgs-status:
    #!/usr/bin/env bash
    set -euo pipefail
    LAST_MODIFIED=$(jq -r '.nodes.nixpkgs.locked.lastModified // empty' flake.lock 2>/dev/null || true)
    if ! [[ "$LAST_MODIFIED" =~ ^[0-9]+$ ]]; then
        echo "nixpkgs last updated: unknown (flake.lock is missing nixpkgs.locked.lastModified or jq is unavailable)"
        exit 0
    fi

    CURRENT_TIME=$(date +%s)
    DAYS_AGO=$(( (CURRENT_TIME - LAST_MODIFIED) / 86400 ))
    if HUMAN=$(date -r "$LAST_MODIFIED" '+%Y-%m-%d %H:%M:%S' 2>/dev/null); then
        :
    elif HUMAN=$(date -d "@$LAST_MODIFIED" '+%Y-%m-%d %H:%M:%S' 2>/dev/null); then
        :
    else
        HUMAN="$LAST_MODIFIED"
    fi
    echo "nixpkgs last updated: $DAYS_AGO days ago ($HUMAN)"

# Profile nix evaluation performance (optionally specify a hostname)
profile host="":
    @./scripts/nix-profile.sh "{{ host }}"

# Display available commands
help:
    @just --list
    @echo "Run 'just <command>' to execute a command."
