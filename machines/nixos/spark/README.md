# DGX Spark cluster

Four DGX Sparks on a MikroTik CRS804 fabric. `spark-01` hosts shared inference
coordination and the deployment-local OCI registry; each declared instance
selects its participant nodes and assigns their roles. The configuration uses
[nixos-dgx-spark](https://github.com/graham33/nixos-dgx-spark).

## Inventory

`nodes.nix` is the single source of truth for flake configuration generation,
installation, and per-node networking.

| Node | Management | Fabric rail 0 | Fabric rail 1 | Role |
| --- | --- | --- | --- | --- |
| `spark-01` | `192.168.1.31` | `10.100.0.1` | `10.100.1.1` | controller |
| `spark-02` | `192.168.1.32` | `10.100.0.2` | `10.100.1.2` | worker |
| `spark-03` | `192.168.1.33` | `10.100.0.3` | `10.100.1.3` | worker |
| `spark-04` | `192.168.1.34` | `10.100.0.4` | `10.100.1.4` | worker |

The management NIC (`enP7s7`, Realtek RTL8127) uses DHCP reservations. Normal
access uses `<node>.local` through Avahi. Both ConnectX-7 rails are untagged
switch access ports on VLAN 100 with MTU 9000 and no default route. The switch
configuration is under `networking/mikrotik-crs804/`.

## Layout

- `hardware/` storage, kernel, and device policy shared by every node.
- `inference/` model acquisition and serving workloads.
- `networking/` node networking and the CRS804 switch config.
- `scripts/` cluster tooling.
- `secrets/` SOPS secrets.
- `docs/`

The flake maps every entry in `nodes.nix` through the shared
`configuration.nix`. Per-node behavior is selected through the `node` module
argument rather than separate host directories.

## Deploy

```bash
just deploy spark-01
just spark-deploy-all
```

`nh os switch` builds through the configured remote builders, copies the
closure to the target, and activates it over SSH. For a networking change,
activate without changing the boot default first:

```bash
nixos-rebuild test \
  --flake .#spark-01 \
  --target-host angel@spark-01.local \
  --use-remote-sudo
```

Rollback is a reboot into the previous systemd-boot generation.

## Documentation

- [Install a node](docs/install-node.md)
- [Inference architecture](../../../packages/inference/docs/architecture.md)
- [Inference implementation](../../../packages/inference/docs/implementation.md)
- [Stage models across the fabric](docs/stage-models.md)
- [Serve models](docs/serve-models.md)

## Secrets

- `spark-01` receives controller-only secrets from `secrets/controller.yaml`.
- Every Spark receives shared secrets from `secrets/shared.yaml`.
- Each permanent host identity must be registered before installation.
- Spark nodes must not be added to the repository-wide secret recipient rule.
