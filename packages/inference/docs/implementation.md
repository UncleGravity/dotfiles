# Inference implementation

## Status

The package implements immutable model artifacts, OCI image publication,
deterministic plans, single-node services, and static clustered services.
Sisyphus runs an authenticated llama.cpp instance independently. Spark supports
single-node vLLM, fabric-only artifact replication, restricted cluster
coordination, and two-node DeepSeek V4 inference.

Behavioral contracts remain canonical in [Artifacts](artifacts.md),
[Recipes](recipes.md), and [Execution](execution.md).

## Principles

- Nix owns declarations, host integration, and long-lived services.
- Effect owns typed I/O, concurrency, interruption, and cleanup inside a unit.
- Pure TypeScript owns planning and normalization.
- Runtime code consumes versioned JSON and never evaluates Nix.
- Existing tools perform downloads, copies, image operations, locking, and
  process supervision.
- Recipe changes do not rebuild the runtime package.
- Deployment-specific recipes and policy remain beside their machines.
- Shared abstractions appear only after demonstrated reuse.

## Source Layout

```text
packages/inference/
|-- package.json
|-- src/
|   |-- entrypoints/   public and systemd executables
|   |-- cli/           command trees and rendering
|   |-- domain/        schemas, artifact identity, planner
|   |-- workflows/     model, image, and instance workflows
|   |   `-- model-store/ immutable artifact validation and publication
|   |-- adapters/      contracts, processes, health probes, flock
|   |-- observability/ versioned progress events, logs, and metrics
|   `-- runtime/       CLI runtime wiring
|-- nix/
|   |-- lib/           internal normalization and contract helpers
|   |-- modules/       the NixOS feature module and recipe option type
|   |-- catalog.nix
|   |-- instances.nix
|   |-- inventory.nix
|   `-- package.nix
|-- tests/
`-- docs/

machines/nixos/sisyphus/inference/
|-- default.nix
`-- recipes/<recipe>/
    |-- default.nix
    |-- Containerfile
    `-- entrypoint.sh    optional recipe-local container logic
```

The `packages/inference/` directory is a reusable engine and NixOS feature, not
a global recipe catalog. Recipes remain with the deployment that owns them.
Promote one only after another deployment uses it unchanged.

Keep one repository flake and lock file. The engine remains extractable
because generic code does not import machine configuration and consumers pass
recipes, inventory, instances, and secrets through the module.

## Technology Boundary

### Nix

Nix owns:

- Catalog, Inventory, and InstanceCatalog generation;
- recipe Containerfiles and immutable build contexts;
- service presence, boot enablement, restart policy, and cleanup commands;
- Podman, the local registry, packages, groups, paths, and permissions;
- deployment-specific recipes and instance topology.

Nix does not own model weights, OCI registry contents, or observed process
state. Those are mutable runtime artifacts.

### TypeScript and Effect

The package installs two public commands:

- `models` manages model archive, local replicas, status, and verification.
- `infer` lists recipes and instances, displays deterministic plans, and watches
  pipeline state.

It also installs internal `infer-instance`, `infer-cluster`, `infer-prepare`, and
`infer-remote` entrypoints for systemd and restricted cluster coordination.
There is no public imperative run command and no privileged general-purpose RPC.

Effect v4 usage stays shallow. Node filesystem and child processes use Effect's
platform services behind the package's narrow adapters; entrypoints assemble
their production Layers once. Planners and argument builders remain ordinary
functions. Command failures and readiness results are schema-backed,
discriminated contracts. The package does not use Effect Cluster, Workflow,
RPC, SQL, or a persistent Effect runtime.

Use Node LTS and exact lock-file versions.

### Observability

Lifecycle reporting uses one versioned `ProgressEvent` contract. Events carry
a stable scope, operation, lifecycle state, message, and optional instance,
node, model, and attributes. The numeric progress variant additionally carries
`current`, `total`, and `unit` fields.

`ProgressEvents` is an Effect `Context.Reference`, so normal services need no
extra runtime dependency. The system runtime writes annotated Effect logs, one
prefixed JSON journal record per event, and
`inference_progress_events_total`. Major preparation and inference lifecycles
use native Effect spans. An OpenTelemetry exporter can be provided at the
runtime boundary without changing workflows.

`infer watch` is a separate process. Its journal adapter replays and follows the
structured records, enriches them with systemd invocation and cursor metadata,
and polls controller unit state. A pure reducer creates a bounded pipeline
snapshot, including node-scoped launch, systemd-readiness, and cleanup
transitions; the initial ANSI view is isolated in the CLI layer. OpenTUI, SSE,
or a web UI can replace that renderer while reusing the adapter and reducer.

`makeProgressHub` remains useful for in-process tests or an embedded consumer,
but it is not the detached transport and does not replace journald history. The
package exposes no network listener or persistent run database. Remote worker
journal aggregation is a separate permission and transport concern; the first
watch view reports only controller-visible cluster phases.

### Host Tools

Adapters invoke programs with argument arrays, never shell evaluation:

- `hf` downloads exact Hugging Face revisions;
- `rsync` resumes archive and fabric copies;
- `sha256sum` performs the full-byte manifest checks;
- `skopeo` resolves registry tags to OCI digests;
- `podman` builds, publishes, restores, and runs containers;
- `flock` serializes local artifacts and allocates a node;
- `systemd-notify` reports endpoint readiness;
- systemd owns lifetime and journald owns logs.

Podman remains preferable to Docker here because the design needs standard
Containerfiles, NVIDIA CDI, exact digests, and foreground integration with
systemd, not a daemon socket.

## NixOS Module

Recipes are regular imported NixOS modules. The deployment interface exposes
only choices that Nix cannot derive:

```nix
{
  imports = [./recipes/qwen3-6-heretic-27b];

  my.inference = {
    enable = true;
    operators = ["angel"];

    instances.qwen = {
      recipe = "qwen3-6-heretic-27b";
      autoStart = true;
    };
  };
}
```

The module derives the local node from `networking.hostName`, its platform from
the evaluated host, the default image platform from that host, standard model
mounts from logical model names, and a loopback registry for a single-node
deployment. The model roots retain overridable defaults. A multi-node
deployment additionally declares `controlNode` and `nodes`; the registry lives
on that control node and uses `fabric0` when present.

The module stays in one file while its wiring is cohesive. Split registry,
node, or Spark control modules only when their implementations become
independently substantial.

Each local instance produces `infer-<name>.service` with:

- a lifetime node `flock`;
- `Type=notify` and endpoint-driven readiness;
- stale-container cleanup before and after execution;
- `Restart=on-failure` with a bounded start rate;
- restart triggers for all three generated contracts;
- optional `WantedBy=multi-user.target` from `autoStart`.

The service runs as root because it uses rootful Podman and may mount root-owned
secrets. This is a smaller privilege boundary than a service account plus an
unattended sudo RPC. Configuration and executable paths are Nix-generated;
runtime args do not come from users. The `infer` group grants operators
model-store access and journal visibility. Normal host administration controls
`systemctl start` and `stop`.

A clustered declaration instead produces `infer-<name>.service` on the control
node and `infer-node-<name>.service` plus `infer-prepare-<name>.service` on each
participant. Only the controller inherits `autoStart`; node and preparation
units are internal implementation details. Each node unit still owns the same
whole-node lock and rootful Podman lifecycle as a single-node service.

Cluster SSH uses the fixed control node's existing Ed25519 host key as its sole
client identity. Public host keys live with addresses and other machine
identity in the deployment node inventory; the NixOS module derives pinned
system `known_hosts` entries and worker authorization from that inventory. No
new secret or private-key mesh is introduced. The `infer-remote` system account
has a forced Nix-store command and Polkit permits only start/stop of matching
`infer-node-*` and `infer-prepare-*` units. Its parser accepts only `prepare`,
`lease`, `stop`, and `status` for a locally declared clustered instance.

The service does not unconditionally require the NAS mount. Model preparation
checks and validates the local replica first; only a missing replica touches
the automounted archive.

## Contract Realization

Nix installs:

```text
/etc/infer/catalog.json
/etc/infer/inventory.json
/etc/infer/instances.json
```

Effect Schema strictly decodes every file and rejects unknown fields or schema
versions. NixOS option types validate recipe declarations, and private Nix
helpers canonicalize generated contracts and reject cross-field errors. Checked
fixtures keep Nix output and TypeScript decoders synchronized:

```text
packages/inference/tests/fixtures/contracts/v1/
|-- catalog.json
|-- instances.json
|-- inventory.json
|-- model-manifest.json
`-- run-plan.json
```

`RunPlan` remains a useful name for the deterministic execution contract. It
is not a mutable run record and does not justify a run store.

## Packaging

`buildNpmPackage` produces one derivation with the public and internal commands
and Node. Its filtered source contains the TypeScript project but not recipes or
documentation, so those changes do not rebuild the engine.

Recipe contexts become separate immutable Nix store paths referenced by the
catalog. They are build inputs, not prebuilt OCI images in the system closure.
The control node uses Podman to build once and publish to its small
local registry. Skopeo resolves the write-once build tag to the exact digest
that Podman runs.

## Validation

- Schema tests reject drift and compare deterministic plans with fixtures.
- Model tests cover interrupted archive/download copies, atomic publication,
  checksums, locks, and warm-local startup without archive access.
- Image tests cover build-once publication, immutable restore, and registry
  failure classification.
- Runtime tests assert exact shell-free Podman arguments and labels, startup
  timeout behavior, consecutive readiness checks, and health-monitor failure.
- `npm run coverage` enforces 80% line, 75% branch, and 80% function coverage.
- Nix checks evaluate recipes, inventories, instances, packaged commands, and
  contract interoperability.

Hardware validation covers:

- authenticated llama.cpp generation, readiness, restart, and cleanup on
  Sisyphus;
- NVIDIA CDI, model preparation, exact image publication, generation, cleanup,
  locking, and failure restart for single-node Spark;
- approximately 3.3 GB/s transfer of a 71.9 GB model from `spark-01` to
  `spark-02` over `fabric0`, followed by full manifest verification;
- real TP=2 DeepSeek V4 generation across `spark-01` and `spark-02`.

The DeepSeek recipe persists compiler and autotuning caches but recreates its
KV cache and max-context workspaces on each start. Its 524,288-token ceiling is
an operational choice to reduce max-length-dependent startup work while
retaining deep-context capacity.
