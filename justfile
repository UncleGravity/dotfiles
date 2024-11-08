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
sync:
    #!/usr/bin/env bash
    echo "🔄 Rebuilding system configuration for {{system_type}}..."
    case "{{system_type}}" in
        "nixos")
            HOSTNAME=$(hostname)
            if ! sudo nixos-rebuild switch --flake .#$HOSTNAME; then
                echo "❌ Failed to rebuild NixOS configuration."
                exit 1
            fi
            ;;
        "darwin")
            HOSTNAME=$(scutil --get ComputerName)
            if ! darwin-rebuild switch --flake .#$HOSTNAME; then
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
    echo "🔗 Creating symlink for Neovim configuration..."
    ln -sfn ~/nix/home/dotfiles/nvim "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim

    echo "🗑️ Deleting zcompdump file"
    # To speed up zsh init, I don't reload the zsh completion cache every time I start zsh.
    # Therefore, each time we add new completions, we need to delete the zcompdump file to it regenerates.
    rm -f "${XDG_CONFIG_HOME:-$HOME/.config}"/zsh/.zcompdump
    echo "✅ Neovim configuration symlink created successfully!"

# Update flake inputs
update:
    @echo "🔄 Updating flake inputs..."
    nix flake update
    @echo "✅ Flake inputs updated successfully!"

# Update flake inputs and rebuild system configuration
upgrade: update sync
    @echo "🎉 System upgrade completed!"

# Synchronize local dotfiles repo with remote, stashing local changes
pull:
    @echo "🔄 Pulling latest changes from remote..."
    git stash
    git pull
    git stash pop
    @echo "✅ Local repository synchronized with remote!"

# Garbage collect old generations (default: 30 days)
gc days="30d":
    @echo "🧹 Performing garbage collection..."
    nix-collect-garbage --delete-older-than {{days}}
    @echo "✅ Garbage collection completed!"

# Remove unused nix store paths
prune:
    @echo "✂️  Pruning unused nix store paths..."
    nix-store --gc
    @echo "✅ Pruning completed!"

###############################################################
# Quick Test - Neovim
###############################################################

nvim-test:
  rm -rf ${HOME}.config/nvim
  ln -sfn $(pwd)/home/dotfiles/nvim ${HOME}/.config/nvim

# List system generations
list-generations:
    #!/usr/bin/env bash
    echo "📋 Listing system generations for {{system_type}}..."
    case "{{system_type}}" in
        "nixos")
            sudo nix-env -p /nix/var/nix/profiles/system --list-generations
            ;;
        "darwin")
            darwin-rebuild list-generations
            ;;
        "home-manager")
            home-manager generations
            ;;
        *)
            echo "❌ Error: Unsupported system type for listing generations."
            exit 1
            ;;
    esac

# Check system status
status:
    @echo "📊 System Status:"
    @echo "System Type: {{system_type}}"
    @echo "Hostname: $(hostname)"
    @echo "Current User: $(whoami)"
    @echo "Nix Version: $(nix --version)"
    @echo "Flake Status:"
    @nix flake metadata

# Display available commands
help:
    @just --list
    @echo "Run 'just <command>' to execute a command."
