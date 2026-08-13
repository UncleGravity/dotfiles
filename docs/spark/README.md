# DGX Spark cluster

Four DGX Sparks on a MikroTik CRS804 fabric. `spark-01` hosts shared inference
coordination and the deployment-local OCI registry; each declared instance
selects its participant nodes and assigns their roles. The configuration uses
[nixos-dgx-spark](https://github.com/graham33/nixos-dgx-spark).

## Inventory

`modules/clan/spark-cluster/inventory.nix` is the source of truth for node
management addresses, MAC addresses, and fabric IDs. The `spark` service
instance in `flake-modules/clan.nix` assigns roles, then
`modules/clan/spark-cluster/` validates and projects the inventory into each
node and Kiwi's monitoring configuration.

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

- `machines/spark-0N/configuration.nix` is the per-machine extension point.
- `modules/clan/spark-cluster/` owns cluster membership, roles, and the shared
  Spark profile import.
- `modules/nixos/profiles/spark/` contains hardware, networking, monitoring,
  inference, and user policy shared by every node.
- `modules/home/profiles/spark.nix` contains the shared Home Manager profile.
- `vars/per-machine/spark-01/` contains controller-only Clan vars.
- `scripts/install-spark-node.sh` installs a node from the NixOS USB image.
- `infra/mikrotik-crs804/` contains the external switch config and runbook.

Clan registers each Spark as an individual machine and applies the shared
profile through the `spark-cluster` service's `node` role. Modules consume the
service's normalized `my.sparkCluster` option.

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

- `spark-01` receives the dedicated coordination key and Hugging Face token
  from the `spark-coordination-spark` and `spark-huggingface-spark` Clan
  generators.
- The console password hash is shared through the `console-password-angel` Clan generator.
- Each permanent host identity must be enrolled in Clan's `openssh` vars before
  installation.
- Spark nodes must not be added to the `secrets/secrets.yaml` recipient rule.
