# AGENTS.md - Nix Configuration Repository

## Build/Test Commands
- `just sync` - Rebuild system configuration (auto-detects NixOS/Darwin/Home Manager)
- `just update` - Update flake inputs
- `just update-sync` - Update inputs and rebuild system
- `nix fmt .` - Format all Nix files using alejandra/treefmt
- `nix flake check` - Validate flake configuration
- `statix check .` - Lint Nix files for best practices
- `vulnix` - Check for security vulnerabilities
- `just nvim` - Create symlink for Neovim config testing
- `just gc [days]` - Garbage collect old generations (default: 30d)
- `just status` - Show system and flake status

## Code Style Guidelines
- **Formatting**: Use `alejandra` formatter via `nix fmt .` (configured in flake.nix)
- **Imports**: Group at top, use relative paths for local modules (e.g., `./modules/home`)
- **Naming**: kebab-case for files/directories, camelCase for Nix attributes
- **Indentation**: 2 spaces, no tabs
- **Strings**: Double quotes for strings, avoid inline comments
- **Functions**: Use `{ ... }:` pattern, follow existing module structure
- **Modules**: Use `imports = [ ... ];` pattern, group related imports

## Error Handling & Types
- Use `lib.mkDefault` for overridable defaults
- Validate with `lib.types` in module options
- Use `assert` for critical requirements
- Prefer `lib.optional` over conditionals

## Git Conventions
- **Format**: `<type>(<scope>): <description>`
- **Types**: `feat`, `fix`, `chore`, `config`, `refactor`, `docs`, `style`
- **Scopes**: Use app names (`nvim`, `zsh`, `kitty`) or system types (`darwin`, `nixos`, `home`)
- **Examples**:
  - `feat(nvim): add telescope file picker`
  - `fix(zsh): correct PATH ordering issue`
  - `config(kitty): update color scheme to gruvbox`
  - `chore: update flake.lock dependencies`
- **Best Practices**:
  - Keep commits atomic (one logical change)
  - Write in imperative mood ("add" not "added")
  - Limit first line to 50 characters when possible
  - Don't mix unrelated changes in one commit
  - NEVER include "Generated with opencode", "Co-Authored-By: opencode", or ANY tool attributions in commit messages
  - Use simple, clean commit messages without any automation signatures

## Testing
- Test configurations with `just sync` before committing
- Use `nix build` to test package builds without installing
- Validate flake with `nix flake check` before pushing changes
