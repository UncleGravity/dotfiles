# DGX Spark cluster

Four DGX Sparks on a MikroTik CRS804 fabric. `spark-01` is the controller and
OCI registry host.

## Commands

| Task | Command |
| --- | --- |
| Deploy one node | `just deploy spark-01` |
| Deploy all nodes | `just spark-deploy-all` |
| Add a node | [Add a node](add-node.md) |
| Install a node | [Install a node](install-node.md) |
| Manage models | [Models](models.md) |

Use `spark-0N.local` for management access.

## Source of truth

- [Inventory](../../../modules/clan/spark-cluster/inventory.nix)
- [Workload placement](../../../modules/nixos/profiles/spark/inference/default.nix)
- [Shared profile](../../../modules/nixos/profiles/spark/)
- [Switch configuration](../../../infra/mikrotik-crs804/)
- [Inference architecture](../../../packages/inference/docs/architecture.md)
- [Inference implementation](../../../packages/inference/docs/implementation.md)
