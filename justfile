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

# Update all flake inputs
update:
    @echo "Updating flake inputs..."
    nix flake update
    @echo "Flake inputs updated successfully!"

# Update all flake inputs and rebuild system configuration
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

# Remove old generations and collect unreferenced store paths.
clean days="30d":
    nh clean all --keep 3 --keep-since "{{ days }}" --ask

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

# Build a NixOS host on the target machine and deploy over SSH.
# Usage: just deploy <hostname>
# Example: just deploy kiwi
deploy host:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Deploying NixOS configuration to {{ host }}..."
    nh os switch . -H "{{ host }}" --target-host "{{ host }}" --build-host "{{ host }}" --elevation-strategy passwordless --ask
    echo "Deployment for '{{ host }}' completed successfully!"

# Manage Portal cloud resources with OpenTofu.
# Usage: just infra init | plan | apply | output
infra *args="plan":
    sops exec-env infra/portal/secrets.env "nix develop -c tofu -chdir=infra/portal {{ args }}"

# Synchronize every tracked SOPS file with the recipient policy in .sops.yaml.
sops-update-keys:
    #!/usr/bin/env bash
    set -euo pipefail

    git ls-files -z -- '*.yaml' '*.yml' '*.json' '*.env' '*.ini' '*.sops' |
        while IFS= read -r -d '' file; do
            [[ -f "$file" ]] || continue
            if status=$(sops filestatus "$file" 2>/dev/null) && [[ "$status" == '{"encrypted":true}' ]]; then
                sops --config .sops.yaml updatekeys --yes "$file"
            fi
        done

# Wipe an enrolled machine and reinstall NixOS with its existing Clan identity.
# Usage: just reinstall portal root@<ip>   (IP: just infra "output portal_ipv4")
reinstall host target:
    ./scripts/reinstall.sh "{{ host }}" "{{ target }}"

# Partition the NVMe, install NixOS with the Clan machine identity, and reboot.
# The node must be booted into the NixOS USB installer first (see its runbook).
spark-install node:
    ./scripts/reinstall.sh "{{ node }}"

# Generate Clan identity and vars for a newly declared Spark node.
spark-enroll node:
    ./scripts/enroll-spark-node.sh "{{ node }}"

# Deploy every Spark declared in the inventory concurrently.
spark-deploy-all:
    nix run .#clan -- machines update \
        --tags spark \
        --host-key-check strict

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
