# DGX Spark cluster

Four DGX Sparks on a MikroTik CRS804 fabric. `spark-01` hosts shared inference
coordination and the deployment-local OCI registry; each declared instance
selects its participant nodes and assigns their roles. The configuration uses
[nixos-dgx-spark](https://github.com/graham33/nixos-dgx-spark).

## Inventory

`modules/nixos/profiles/spark/nodes.nix` is the single source of truth for
flake configuration generation, installation, and per-node networking.

| Node | Management | Fabric rail 0 | Fabric rail 1 | Role |
| --- | --- | --- | --- | --- |
| `spark-01` | `192.168.1.31` | `10.100.0.1` | `10.100.1.1` | controller |
| `spark-02` | `192.168.1.32` | `10.100.0.2` | `10.100.1.2` | worker |
| `spark-03` | `192.168.1.33` | `10.100.0.3` | `10.100.1.3` | worker |
| `spark-04` | `192.168.1.34` | `10.100.0.4` | `10.100.1.4` | worker |

The management NIC (`enP7s7`, Realtek RTL8127) uses DHCP reservations. Normal
access uses `<node>.local` through Avahi. Both ConnectX-7 rails are untagged
switch access ports on VLAN 100 with MTU 9000 and no default route. The switch
configuration is under `infra/mikrotik-crs804/`.

## Layout

- `machines/spark-0N/configuration.nix` identifies each managed machine and
  imports the shared profile.
- `modules/nixos/profiles/spark/` contains hardware, networking, monitoring,
  inference, and user policy shared by every node.
- `modules/home/profiles/spark.nix` contains the shared Home Manager profile.
- `secrets/spark/controller.yaml` contains controller-only SOPS secrets.
- `scripts/install-spark-node.sh` installs a node from the NixOS USB image.
- `infra/mikrotik-crs804/` contains the external switch config and runbook.

Clan registers each Spark as an individual machine. The shared profile remains
single-source; per-node values are selected from `nodes.nix` through the
transitional `node` module argument.

## Deploy

```bash
just deploy spark-01
just spark-deploy-all
```

`nh os switch` builds on each Spark itself, copies the closure to the target,
and activates it over SSH. Ambient remote builders are disabled explicitly.
For a networking change, activate without changing the boot default first:

```bash
nixos-rebuild test \
  --flake .#spark-01 \
  --target-host angel@spark-01.local \
  --build-host angel@spark-01.local \
  --builders "" \
  --use-remote-sudo
```

Rollback with `sudo nixos-rebuild switch --rollback` and verify the services
before rebooting.

## Documentation

- [Install a node](install-node.md)
- [Inference architecture](../../packages/inference/docs/architecture.md)
- [Inference implementation](../../packages/inference/docs/implementation.md)
- [Stage models across the fabric](stage-models.md)
- [Serve models](serve-models.md)

## Secrets

- `spark-01` receives controller-only secrets from `secrets/spark/controller.yaml`.
- The console password hash is shared through the `console-password-angel` Clan generator.
- Each permanent host identity must be registered before installation.
- Spark nodes must not be added to the `secrets/secrets.yaml` recipient rule.
