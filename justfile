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
    echo "Error: Unable to determine system type. Supported types are NixOS, Darwin, and Home Manager." >&2
    exit 1
fi
`

# Rebuild the system configuration
sync:
    #!/usr/bin/env bash
    echo "Rebuilding system configuration for {{system_type}}..."
    case "{{system_type}}" in
        "nixos")
            HOSTNAME=$(hostname)
            sudo nixos-rebuild switch --flake .#$HOSTNAME
            ;;
        "darwin")
            HOSTNAME=$(scutil --get ComputerName)
            darwin-rebuild switch --flake .#$HOSTNAME
            ;;
        "home-manager")
            USERNAME=$(whoami)
            home-manager switch --flake .#$USERNAME
            ;;
    esac

# Update flake inputs
update:
    @echo "Updating flake inputs..."
    nix flake update

# Update flake inputs and rebuild system configuration
upgrade: update sync

# Synchronize local dotfiles repo with remote, stashing local changes
pull:
    @echo "Pulling latest changes from remote..."
    git stash
    git pull
    git stash pop

# Garbage collect old generations (default: 30 days)
gc days="30d":
    @echo "Performing garbage collection..."
    nix-collect-garbage --delete-older-than {{days}}

# Remove unused nix store paths
prune:
    @echo "Pruning unused nix store paths..."
    nix-store --gc

# List system generations
list-generations:
    #!/usr/bin/env bash
    echo "Listing system generations for {{system_type}}..."
    case "{{system_type}}" in
        "nixos")
            sudo nix-env -p /nix/var/nix/profiles/system --list-generations
            ;;
        "darwin")
            darwin-rebuild --list-generations
            ;;
        "home-manager")
            home-manager generations
            ;;
        *)
            echo "Error: Unsupported system type for listing generations."
            exit 1
            ;;
    esac

# Display available commands
help:
    @just --list