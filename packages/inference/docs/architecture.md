# Inference architecture

## Status

This document defines the implemented architecture. Sisyphus runs independent
single-node inference. Spark supports single-node services, fabric-only artifact
distribution, and static multi-node services; the two-node DeepSeek V4 recipe
has served OpenAI-compatible requests across `spark-01` and `spark-02`.

- [Artifacts](artifacts.md) owns model and image identity and preparation.
- [Recipes](recipes.md) owns workload declarations.
- [Execution](execution.md) owns instance planning, services, and recovery.
- [Implementation](implementation.md) owns technology and source boundaries.

## Goals

- Download each selected Hugging Face artifact once into a canonical archive.
- Run inference only from verified local NVMe replicas.
- Copy weights between Sparks only over the CX-7 fabric.
- Build recipe images once and run exact OCI digests.
- Block clustered service readiness until every participant is ready.
- Let Sisyphus operate without any Spark dependency.
- Keep recipes declarative without turning runtime flags into NixOS options.
- Expose stable JSON contracts and a read-only pipeline view for operators.

## Non-goals

- Serving weights from the NAS during inference.
- Allowing inference containers to download models.
- Encoding downloaded artifacts in the Nix store.
- Building a general scheduler, container DSL, or distributed database.
- Creating arbitrary topologies at runtime.
- Running more than one inference allocation on a node.
- Coordinating Sisyphus and Spark as one deployment.

## Deployments

Spark and Sisyphus are independent deployments:

| Deployment | Nodes | Control node | Registry |
| --- | --- | --- | --- |
| Spark | `spark-01` through `spark-04` | `spark-01` | Spark fabric endpoint |
| Sisyphus | `sisyphus` | `sisyphus` | Sisyphus loopback |

They may read the same NAS archive, but do not share services, registries,
local replicas, or runtime state. Each deployment receives three Nix-generated
contracts:

```text
/etc/infer/catalog.json    recipes
/etc/infer/inventory.json  hosts and artifact locations
/etc/infer/instances.json  named service deployments
```

## Components

1. **Recipe catalog** declares complete workloads and immutable build inputs.
2. **Inventory** declares nodes, storage roots, the control node, and registry.
3. **Instance catalog** binds a name and node topology to a recipe.
4. **Planner** converts those declarations into a deterministic `RunPlan`.
5. **Model store** archives and materializes verified model artifacts.
6. **Image store** builds, publishes, resolves, and restores OCI images.
7. **Instance runtime** prepares a plan and runs its foreground container.
8. **systemd** owns service lifetime, desired state, restart policy, and boot.
9. **journald** owns logs and service history.
10. **Pipeline observer** reduces structured journal events and unit state into a
    replaceable terminal view.

The composition is deliberately small:

```text
Recipe + Inventory + Instance -> deterministic RunPlan
RunPlan + prepared artifacts   -> foreground instance runtime
Nix instance declaration       -> systemd service
```

There is no custom run database, UUID lifecycle, reconciliation daemon, or
privileged JSON RPC. The declaration is durable state; systemd is observed
state.

The observer is not part of the inference service and has no control channel to
it. Journald is the replay transport, `_SYSTEMD_INVOCATION_ID` identifies a
systemd run, a pure reducer owns the current pipeline snapshot, and the ANSI
renderer is only one consumer. A later OpenTUI or web renderer can consume the
same snapshots without changing workflow instrumentation or introducing another
source of truth.

## Invariants

- A final model path exists only after its complete tree passes the manifest
  contract.
- Published artifact identities are immutable.
- `ensure` is idempotent, resumable, and successful only after verification.
- A warm local model can start without contacting the NAS.
- Containers receive only local model paths and an exact image digest.
- Planning performs no runtime I/O and contains no timestamps or observations.
- A node belongs to at most one inference instance at a time.
- A service reports ready only after consecutive successful health checks.
- systemd stopping or failure cleanup removes the named container.
- Sisyphus has no runtime dependency on a Spark host.

## Control role

The control node is deployment configuration, not necessarily an inference
participant. It owns image publication and coordination of statically declared
cluster nodes. Fixing Spark
coordination and registry placement to `spark-01` avoids leader election,
distributed state, and a private-key mesh.

Instance topology remains flexible because it is data in Nix. For example,
separate instances can declare `spark-01,spark-02` and
`spark-03,spark-04`. They may be present with `autoStart = false` and started
as needed. The node lock rejects overlapping allocations.

Sisyphus is its own control node, registry host, and only execution node. Its
current service therefore needs no remote control transport.
