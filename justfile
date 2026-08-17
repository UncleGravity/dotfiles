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
            nh os switch . -H "$HOSTNAME" --builders ""
            ;;
        "darwin")
            HOSTNAME=$(scutil --get LocalHostName 2>/dev/null || hostname -s)

            # Check if Rosetta 2 is available
            if ! arch -x86_64 /bin/bash -c 'exit 0' 2>/dev/null; then
                echo "WARNING: Rosetta 2 not available. Intel packages may fail."
                echo ""
            fi

            nh darwin switch . -H "$HOSTNAME" --builders ""
            ;;
        "home-manager")
            USERNAME=$(whoami)
            nh home switch . -c "$USERNAME" --builders ""
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
    nix fmt --builders "" .

# Validate the flake
check:
    nix flake check --builders ""

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

    DISKO_CONFIG="./machines/{{ hostname }}/hardware/disko.nix"

    if [ ! -f "$DISKO_CONFIG" ]; then
        echo "❌ Disko configuration file not found: $DISKO_CONFIG"
        exit 1
    fi

    echo "Running Disko with config: $DISKO_CONFIG"
    sudo nix --builders "" --extra-experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount "$DISKO_CONFIG"
    echo "Disko command completed successfully!"

# Build a NixOS host on the target machine and deploy over SSH.
# Usage: just deploy <hostname>
# Example: just deploy kiwi
deploy host:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Deploying NixOS configuration to {{ host }}..."
    nh os switch . -H "{{ host }}" --target-host "{{ host }}" --build-host "{{ host }}" --builders "" --elevation-strategy passwordless --ask
    echo "Deployment for '{{ host }}' completed successfully!"

# Manage cloud resources (infra/) with OpenTofu.
# Usage: just infra init | plan | apply | output
infra *args="plan":
    sops exec-env infra/secrets.env "nix develop --builders '' -c tofu -chdir=infra {{ args }}"

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

# Wipe a machine and install NixOS with its Clan machine identity.
# Usage: just provision portal root@<ip>   (IP: just infra "output portal_ipv4")
provision host target:
    nix develop --builders "" -c ./scripts/provision.sh "{{ host }}" "{{ target }}"

# Partition the NVMe, install NixOS with the Clan machine identity, and reboot.
# The node must be booted into the NixOS USB installer first (see its runbook).
spark-install node:
    nix develop --builders "" -c ./scripts/install-spark-node.sh "{{ node }}"

# Deploy all four Sparks concurrently.
spark-deploy-all:
    #!/usr/bin/env bash
    set -uo pipefail

    nodes=(spark-01 spark-02 spark-03 spark-04)
    log_dir=$(mktemp -d)
    declare -A node_by_pid=()
    failures=()

    cleanup() {
        rm -rf "$log_dir"
    }
    trap cleanup EXIT

    for node in "${nodes[@]}"; do
        echo "Starting deployment for '$node'..."
        (
            nh os switch . \
                -H "$node" \
                --target-host "$node" \
                --build-host "$node" \
                --builders "" \
                --elevation-strategy passwordless
        ) >"$log_dir/$node.log" 2>&1 &
        node_by_pid[$!]="$node"
    done

    remaining=${#nodes[@]}
    while ((remaining > 0)); do
        completed_pid=""
        if wait -n -p completed_pid; then
            status=0
        else
            status=$?
        fi

        node=${node_by_pid[$completed_pid]}
        if ((status == 0)); then
            echo "Deployment for '$node' completed successfully!"
        else
            echo "Deployment for '$node' failed with status $status:" >&2
            sed "s/^/[$node] /" "$log_dir/$node.log" >&2
            failures+=("$node")
        fi

        unset 'node_by_pid[$completed_pid]'
        ((remaining -= 1))
    done

    if ((${#failures[@]} > 0)); then
        printf 'Failed Spark deployments: %s\n' "${failures[*]}" >&2
        exit 1
    fi

    echo "All Spark deployments completed successfully!"

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
