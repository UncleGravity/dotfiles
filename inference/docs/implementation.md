# Inference implementation

## Status

The contract, model, image, and Sisyphus static-service slices are implemented
and validated. `infer-qwen.service` has passed deployment, readiness,
authenticated generation, controlled stop/start, node-lock, and automatic
crash-recovery checks on Sisyphus. The single-node Spark path has also passed
archive migration, verified local materialization, image publication by exact
digest, systemd readiness, OpenAI-compatible generation, controlled restart,
container cleanup, node-lock reacquisition, and automatic crash recovery with
Laguna. Laguna remains a manually started, unauthenticated trusted-LAN service
in v1. Its upstream runtime warnings are deferred recipe work. Spark model
replication over the fabric, worker access to the local image registry, and the
restricted coordination SSH boundary have been validated between `spark-01`
and `spark-02`. The generic two-node lifecycle has also passed readiness,
coordinated stop, worker-failure detection, and automatic whole-cluster
recovery. Reboot behavior and a complete run using a real distributed recipe
have not been validated.

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
inference/
|-- package.json
|-- src/
|   |-- entrypoints/   public and systemd executables
|   |-- cli/           command trees and rendering
|   |-- domain/        schemas, artifact identity, planner
|   |-- workflows/     model, image, and instance workflows
|   |-- adapters/      filesystem contracts, processes, flock
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

The top-level `inference/` directory is a reusable engine and NixOS feature,
not a global recipe catalog. Recipes remain with the deployment that owns
them. Promote one only after another deployment uses it unchanged.

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
- `infer` lists recipes and instances and displays deterministic plans.

It also installs `infer-instance`, an internal foreground entrypoint for
systemd. There is no public imperative run command and no privileged RPC.

Effect usage stays shallow. Node filesystem and command execution are
replaceable services; entrypoints assemble their production Layers once.
Planners and argument builders remain ordinary functions. V1 does not need
Effect Cluster, Workflow, RPC, SQL, or a persistent Effect runtime.

Use Node LTS and exact lock-file versions. A future OpenTUI client can be a
separate Bun application that consumes the JSON contracts and systemd data;
OpenTUI does not need to run on inference nodes.

### Host Tools

Adapters invoke programs with argument arrays, never shell evaluation:

- `hf` downloads exact Hugging Face revisions;
- `rsync` resumes archive and future fabric copies;
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

The service runs as root because v1 uses rootful Podman and root-owned secret
mounts. This is a smaller privilege boundary than a service account plus an
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
inference/tests/fixtures/contracts/v1/
|-- catalog.json
|-- instances.json
|-- inventory.json
|-- model-manifest.json
`-- run-plan.json
```

`RunPlan` remains a useful name for the deterministic execution contract. It
is not a mutable run record and does not justify a run store.

## Packaging

`buildNpmPackage` produces one derivation with `models`, `infer`,
`infer-instance`, and Node. Its filtered source contains the TypeScript project
but not recipes or documentation, so those changes do not rebuild the engine.

Recipe contexts become separate immutable Nix store paths referenced by the
catalog. They are build inputs, not prebuilt OCI images in the system closure.
The control node uses Podman to build once and publish to its small
local registry. Skopeo resolves the write-once build tag to the exact digest
that Podman runs.

## Testing

- Schema tests reject drift and compare deterministic plans with fixtures.
- Model tests cover interrupted archive/download copies, atomic publication,
  checksums, locks, and warm-local startup without archive access.
- Image tests cover build-once publication, immutable restore, and registry
  failure classification.
- Runtime tests assert exact shell-free Podman arguments and labels.
- Nix checks evaluate recipes, inventories, instances, packaged commands, and
  contract interoperability.
- Hardware validation covers NVIDIA CDI, systemd readiness, API behavior,
  reboot, crash recovery, and later fabric-only Spark transfer.

The first Laguna cold start established the full Spark path. Model copy and
verification took about seven minutes, image publication took less than one
minute, and the original vLLM loading path took several minutes. These are
observations, not timeout or performance contracts. Explicitly selecting
`fastsafetensors` reduced the reported weight-loading phase from 472.53 seconds
to about 21 seconds on `spark-01`, approximately 22.5 times faster. A forced
container exit was detected immediately, cleaned up, and restarted
automatically.

The first Spark-to-Spark artifact test copied the 71.9 GB Laguna primary model
from `spark-01` to `spark-02` over `fabric0` in about 22 seconds, approximately
3.3 GB/s. The original Effect file stream then spent about 5.5 minutes hashing
the replica. A hardware benchmark showed GNU `sha256sum` hashing a 4.8 GB shard
in about 2.3 seconds, so checksum execution was delegated to that existing host
tool while Effect retained validation and publication ownership.
With that change deployed, `models verify` checked both the 71.9 GB NAS archive
and the 71.9 GB local replica in about 3 minutes 45 seconds; the NAS read was the
remaining bottleneck.

The two-node `cluster-smoke` instance validated the generic clustered lifecycle
without involving CUDA or a distributed inference runtime. The corrected image
started on both nodes from one published digest and reported ready in about
nine seconds. Coordinated stop removed both containers cleanly in about 1.4
seconds. Killing the worker container caused the controller to fail the run;
systemd restarted it after five seconds, and both nodes were healthy again
about eight seconds later. This proves orchestration and recovery, not real
multi-node inference behavior.

## Milestones

| Milestone | Deliverable | Status |
| --- | --- | --- |
| 1. Contract spine | Effect package, strict schemas, Nix constructors, deterministic planner | Complete |
| 2. Local models | Immutable archive and local replica workflows | Complete |
| 3. Local images | Loopback registry, build identity, digest publication and restore | Complete |
| 4. Static Sisyphus service | Nix instance declaration, `infer-qwen`, readiness, cleanup, restart | Complete |
| 5. Single-node Spark service | Laguna archive, local replicas, image publication, readiness, generation | Complete |
| 6. Spark artifacts | Fabric-only replica distribution and remote digest restore | Complete |
| 7. Clustered instances | Ordered static control/node units, endpoint readiness, stop, and recovery | Complete |
| 8. Distributed recipe | Recipe-local head/worker runtime and multi-node generation | Implemented; hardware validation pending |
| 9. Hardening | Reboot behavior, operations guide, and migration cleanup | In progress |

The Spark milestone should extend static instances, not recreate imperative
run IDs or a general control plane.
