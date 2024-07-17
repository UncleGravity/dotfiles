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

# Display available commands
help:
    @just --list