# Personal Nix Config

What are you doing here?

[Documentation](docs/README.md)

## Commands

| Task | Command |
| --- | --- |
| Rebuild this host | `just sync` |
| Deploy a NixOS host | `just deploy <hostname>` |
| Update all flake inputs and rebuild | `just update-sync` |
| Validate the flake | `just check` |
| Lint Nix files | `just lint` |
| List all commands | `just` |

## Provisioning

- [Install NixOS](docs/operations/install-nixos.md)
- [Provision a Mac](docs/operations/install-macos.md)
- [Install a Spark node](docs/machines/spark/install-node.md)

## Remote builds

Builds run locally by default. Use `nix-remote` to opt into the
configured aarch64-linux and x86_64-linux nixbuild.net builders:

```sh
nix-remote build .#<package>
```

## Layout

| Path | Purpose |
| --- | --- |
| `machines/` | Per-machine configuration |
| `modules/` | Shared NixOS, nix-darwin, Home Manager, and Clan modules |
| `flake-modules/` | Flake outputs and composition |
| `infra/` | OpenTofu-managed infrastructure |
| `docs/` | Architecture notes and whatever else I feel like |
