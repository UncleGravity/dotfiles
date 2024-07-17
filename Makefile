SYSTEM_TYPE := $(shell \
    if [ -d /etc/nixos ]; then \
        echo "nixos"; \
    elif command -v darwin-rebuild >/dev/null 2>&1; then \
        echo "darwin"; \
    elif command -v home-manager >/dev/null 2>&1; then \
        echo "home-manager"; \
    else \
        echo "Error: Unable to determine system type. Supported types are NixOS, Darwin, and Home Manager." >&2; \
        exit 1; \
    fi \
)

sync: ## Rebuild the system configuration
	@echo "Rebuilding system configuration for $(SYSTEM_TYPE)..."
	@case "$(SYSTEM_TYPE)" in \
		"nixos") \
			HOSTNAME=$$(hostname); \
			nixos-rebuild switch --flake .#$$HOSTNAME ;; \
		"darwin") \
			HOSTNAME=$$(scutil --get ComputerName); \
			darwin-rebuild switch --flake .#$$HOSTNAME ;; \
		"home-manager") \
			USERNAME=$$(whoami); \
			home-manager switch --flake .#$$USERNAME ;; \
	esac

update: ## Update flake inputs
	@echo "Updating flake inputs..."
	@nix flake update

upgrade: update sync ## Update flake inputs and rebuild system configuration

pull: ## Synchronize local dotfiles repo with remote, stashing local changes
	@echo "Pulling latest changes from remote..."
	@git stash
	@git pull
	@git stash pop

gc: ## Garbage collect old generations (default: 30 days)
	@echo "Performing garbage collection..."
	@nix-collect-garbage --delete-older-than ${DAYS:-30d}

.PHONY: help

help: ## Display available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'