# AGENTS.md - Nix Configuration Repository

## Build/Test Commands
- `just sync` - Rebuild system configuration (auto-detects NixOS/Darwin/Home Manager)
- `just update` - Update flake inputs
- `just update-sync` - Update inputs and rebuild system
- `nix fmt .` - Format all Nix files using alejandra
- `nix flake check` - Validate flake configuration
- `statix check .` - Lint Nix files for best practices
- `vulnix` - Check for security vulnerabilities

## Code Style Guidelines
- **Formatting**: Use `alejandra` formatter (run `nix fmt .`)
- **Imports**: Group imports at top, use relative paths for local modules
- **Naming**: Use kebab-case for files/directories, camelCase for Nix attributes
- **Comments**: Use `#` for single-line, avoid inline comments unless necessary
- **Indentation**: 2 spaces, no tabs
- **Strings**: Use double quotes for strings, single quotes for paths
- **Functions**: Use `{ ... }:` pattern for function arguments
- **Modules**: Follow `imports = [ ... ];` pattern, group related imports

## Error Handling
- Use `lib.mkDefault` for overridable defaults
- Validate inputs with `lib.types` in module options
- Use `assert` statements for critical requirements
- Prefer `lib.optional` over conditionals where possible

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
  - **DO NOT** include "Generated with opencode" or similar tool attributions in commit messages

## Testing
- Test configurations with `just sync` before committing
- Use `nix build` to test package builds without installing
- Validate flake with `nix flake check` before pushing changes