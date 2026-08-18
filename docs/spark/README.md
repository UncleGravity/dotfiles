# DGX Spark cluster

A DGX Spark cluster with four current nodes on a MikroTik CRS804 fabric.
`spark-01` hosts shared inference coordination and the deployment-local OCI
registry; each declared instance selects its participant nodes and assigns
their roles. The configuration uses
[nixos-dgx-spark](https://github.com/graham33/nixos-dgx-spark).

## Inventory

`modules/clan/spark-cluster/inventory.nix` is the source of truth for nodes,
the generic control-plane host, management addresses, MAC addresses, and fabric
IDs. The `spark` service instance in `flake-modules/clan.nix` assigns those
infrastructure roles, then
`modules/clan/spark-cluster/` validates and projects the inventory into each
node and Kiwi's monitoring configuration.

| Node | Management | Fabric rail 0 | Fabric rail 1 | Role |
| --- | --- | --- | --- | --- |
| `spark-01` | `192.168.1.31` | `10.100.0.1` | `10.100.1.1` | controller |
| `spark-02` | `192.168.1.32` | `10.100.0.2` | `10.100.1.2` | worker |
| `spark-03` | `192.168.1.33` | `10.100.0.3` | `10.100.1.3` | worker |
| `spark-04` | `192.168.1.34` | `10.100.0.4` | `10.100.1.4` | worker |

The node role can grow independently of inference workloads. Recipes declare
runtime constraints such as supported node counts, while
`modules/nixos/profiles/spark/inference/default.nix` explicitly assigns real
machines to each instance. Adding a fleet member does not silently change an
existing inference instance.

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
- `modules/nixos/profiles/spark/inference/default.nix` owns concrete workload
  placement; its `recipes/` subtree owns reusable runtime definitions.
- `modules/home/profiles/spark.nix` contains the shared Home Manager profile.
- `vars/per-machine/spark-01/` contains controller-only Clan vars.
- `scripts/enroll-spark-node.sh` creates reviewed Clan state for a new node.
- `scripts/reinstall.sh` installs an enrolled node from the NixOS USB image
  through Clan.
- `infra/mikrotik-crs804/` contains the external switch config and runbook.

Clan registers each Spark as an individual machine and applies the shared
profile through the `spark-cluster` service's `node` role. Modules consume the
service's normalized `my.sparkCluster` option.

To add a machine, declare it in the inventory and add its empty per-machine
module, then run `just spark-enroll <node>` before touching its disk. The full
procedure and physical networking prerequisites are in
[Install a node](install-node.md).

## Deploy

```bash
just deploy spark-01
just spark-deploy-all
```

`just deploy` updates one node through `nh`. `just spark-deploy-all` asks Clan
to update every machine tagged `spark`; Clan runs those updates concurrently
and builds on each target. The batch command uses strict SSH host-key checking,
disables ambient remote builders, and requests the operator Age identity from
1Password once for its var-upload phase.
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
