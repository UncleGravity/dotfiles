## Build/Test Commands
- `just sync` - Rebuild system configuration (auto-detects NixOS/Darwin/Home Manager)
- `nix flake check --builders ""` - Validate the flake without ambient remote builders
- `statix check .` - Lint Nix files for best practices

## Tools

**optnix** - Search and explore this repository's configuration options
- Always run `optnix` with escalated permissions; it requires Nix daemon access.
- `optnix -l` - List all evaluated configurations for the local flake (banana, kiwi, etc, and their Home Manager modules)
- `optnix -n -s <config-name> <option>` - Search for specific options (e.g., `optnix -n -s banana programs.zsh.enable`)

**nh search** / **gh search** - Search nixpkgs and nixos options
- `nh search <package> --limit <number>` - Search nixpkgs for packages (e.g., `nh search cargo --limit 5`)

**Clan**
- The repository's `clan` package prefers an explicit SOPS Age identity or the standard local `~/.config/sops/age/keys.txt` file.
- When no local identity is available, it runs the pinned Clan CLI through 1Password and injects the operator identity only into that process.
- Use `nix run .#clan-unwrapped -- ...` only for troubleshooting without 1Password.

**searching**
- Use `fd` isntead of `find` when possible.
- Use `rg` and `ast-grep` instead of `grep` when possible.
- Use `nu` for handling complex structured data instead of sed/awk/jq/etc

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
- Use `nix build --builders ""` to test package builds without installing
- Validate flake with `nix flake check --builders ""` before pushing changes
- Never inherit configured remote builders during repository validation. Spark builds use the target Spark as `--build-host` and still pass `--builders ""`.

Never use `path:`/`builtins.path`; they copy (sometimes large) untracked files to the store.
Instead ask to stage the relevant files.
