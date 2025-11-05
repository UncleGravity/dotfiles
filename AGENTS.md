# AGENTS.md - Nix Configuration Repository

## Build/Test Commands
- `just sync` - Rebuild system configuration (auto-detects NixOS/Darwin/Home Manager)
- `nix fmt .` - Format all Nix
- `nix flake check` - Validate flake configuration
- `statix check .` - Lint Nix files for best practices

## Configuration Discovery Tools
When exploring or modifying configurations, use these tools to understand available options:

**optnix** - Search and explore this repository's configuration options
- `optnix -n -l` - List all evaluated configurations for the local flake (banana, nixos, kiwi, pi, BASURA and their Home Manager modules)
- `optnix -n -s <config-name> <option>` - Search for specific options (e.g., `optnix -n -s banana programs.zsh.enable`)
- **Note**: Always use `-n / --non-interactive` flag when running optnix from scripts or non-interactive contexts

**nh search** / **gh search** - Search nixpkgs and nixos options
- `nh search <package> --limit <number>` - Search nixpkgs for packages (e.g., `nh search cargo --limit 5`)

## Code Style Guidelines
- **Formatting**: Use `alejandra` formatter via `nix fmt .` (configured in flake.nix)
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
