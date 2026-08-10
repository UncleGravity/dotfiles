# Inference execution

## Status

Sisyphus and Spark run declared inference instances as NixOS services. The
single-node path and the static two-node lifecycle have been hardware-validated,
including model and image preparation, ordered startup, readiness, coordinated
stop, lease-loss cleanup, and OpenAI-compatible generation from the distributed
DeepSeek V4 service.

## Instance Declaration

A recipe describes a workload. An instance describes where and whether that
workload runs:

```nix
my.inference.instances.qwen = {
  recipe = "qwen3-6-heretic-27b";
  autoStart = true;
};
```

On a single-node deployment, omitted `nodes` selects the local node. A Spark
instance declares an ordered node list explicitly:

```nix
my.inference.instances.deepseek-v4-flash-0731 = {
  recipe = "deepseek-v4-flash-0731";
  nodes = ["spark-01" "spark-02"];
  autoStart = false;
};
```

The first node is the API/head node; remaining nodes are workers. Nix preserves
that order and validates recipe existence, node membership, node count, and
platform compatibility. It writes `/etc/infer/instances.json` and creates the
corresponding services. Changing topology is a configuration change and
therefore requires deployment.

## Operator Interface

The `infer` CLI is read-only:

```text
infer recipes list
infer instances list
infer plan qwen
```

Use native systemd commands for lifecycle and journald for logs:

```text
systemctl start infer-qwen
systemctl stop infer-qwen
systemctl restart infer-qwen
systemctl status infer-qwen
journalctl -u infer-qwen -f
```

`autoStart = true` adds the service to `multi-user.target`; false leaves it
installed for manual use. There is no separate reconcile service because
systemd already stores enabled state, restores boot services, monitors the
process, and applies restart policy.

Structured clients should read `/etc/infer/*.json`, `models status --json`,
systemd properties, and journald JSON. They do not need a second run-state
database.

## Planning

`RunPlan` is a deterministic document produced from the three static
contracts. Despite its name, it is not a persisted imperative run record. It
contains:

- recipe identity and startup order;
- selected nodes, head, roles, and ranks;
- immutable model identities and resolved local mount paths;
- image build identity;
- complete per-node container declarations;
- endpoint and startup timeout.

It contains no run ID, image observation, timestamp, process state, or mutable
intent. Repeated planning over identical contracts produces identical JSON.

## Single-Node Lifecycle

Starting `infer-qwen.service` performs one foreground workflow:

1. `flock` acquires `/var/lib/infer/node.lock` for the service lifetime.
2. The runtime decodes Catalog, Inventory, and InstanceCatalog.
3. The planner reconstructs and validates the instance plan.
4. Each model is checked on local NVMe first. A missing replica is copied from
   the archive into staging, verified, and atomically published.
5. The image build tag is resolved. A missing image is built and published;
   Podman restores the exact digest locally when needed.
6. Podman runs one named foreground container with local read-only model
   mounts, the recipe entrypoint args, and `--pull=never`.
7. Two consecutive endpoint checks cause `systemd-notify --ready`.
8. Three consecutive failures, or an unexpected container exit, fail the
   service and let systemd apply `Restart=on-failure`.

The runtime emits versioned lifecycle events while it loads contracts, ensures
each model, prepares the image, launches the container, and waits for readiness.
The default event service writes annotated Effect logs to journald and records
an Effect metric. Model preparation additionally reports copy, verification,
and atomic publication phases. The event contract supports numeric progress,
but the current command adapters do not yet parse per-byte transfer or checksum
progress from their tools. Startup health checks run every two seconds; after
readiness, monitoring runs every ten seconds, so three failed checks represent
roughly thirty seconds of sustained endpoint failure.

The service uses the stable container name `infer-<instance>`. OCI labels
record instance, recipe hash, image digest, role, and systemd
invocation ID. Podman's separate log storage is disabled; stdout and stderr go
directly to the unit journal.

## Allocation

Each node uses one non-blocking whole-node `flock`. It prevents two declared
services from using the same GPU node at once without introducing a scheduler
or lock database. The lock follows the service process and disappears after any
exit, including a crash.

For expected alternatives, declare several `autoStart = false` instances and
start one. Starting an overlapping instance fails; systemd's start limit
prevents an unbounded retry loop.

Spark enables host memory protection for every inference workload. Podman
leaves container payloads in their node unit's cgroup under
`inference.slice`. The node unit limits CPU-accounted memory and raises the
workload's OOM victim priority. Swap is prohibited by default; deployments can
set `my.inference.allowSwap` for unified-memory workloads that require disk
backing. Spark declares a 32 GiB swapfile for GLM 5.2 and uses a swappiness of
1, allowing inactive Ray memory to move without encouraging routine swapping.
Earlyoom monitors host-available memory instead of PSI stall time, which avoids
treating expected GB10 unified-memory reclaim as an OOM. It sends `SIGTERM`
below 2% available memory and `SIGKILL` below 1%; the inference score makes the
workload the preferred victim. GB10 CUDA allocations are not fully represented
by cgroup memory counters, so recipes must still reserve explicit unified-memory
headroom. A terminated container stops its node unit so the cluster controller
can clean up the remaining participants.

`my.inference.memoryMaxPercent` controls the per-node cgroup limit and defaults
to 90. Deployments may raise it for workloads that require more unified memory.

## Stopping and Recovery

`systemctl stop` invokes `podman stop`, then force-removes any remaining named
container. `ExecStartPre` also removes stale containers before every start,
and `ExecStopPost` runs on failed starts. These operations use Podman's
idempotent `--ignore` behavior.

Consequences:

- closing an SSH session does not stop inference;
- a single-node runtime or container crash becomes a failed invocation and uses
  `Restart=on-failure`;
- a clustered failure stops every participant and leaves the control unit
  failed for explicit operator review; it does not retry the whole cluster;
- a host reboot restores only instances with `autoStart = true`;
- an interrupted model copy remains resumable below `.staging`;
- no stale desired-state file can resurrect a removed instance;
- logs and previous invocations remain queryable through journald.

## Clustered Spark Services

Spark keeps the same instance declaration and deterministic plan. Nix creates a
static control unit on `spark-01`, a node unit on each participant, and a local
preparation oneshot on each participant:

1. The controller prepares one verified model seed and the image digest.
2. It invokes participant preparation sequentially. Missing replicas pull from
   `spark-01` over `fabric0`; workers restore the published image by exact
   digest and cannot build a missing tag.
3. A forced SSH helper accepts only `prepare`, `lease`, `stop`, and `status` for
   a clustered instance allocated to that local node.
4. Node units run their planned local role and hold their local node locks. The
   recipe's `startOrder` determines whether the head or workers start first.
5. The control unit reports ready only after every unit is active and the head
   endpoint is healthy. A recipe entrypoint must not expose that endpoint until
   its own distributed runtime is ready.
6. Each remote node runs under a long-lived restricted SSH lease. Clean stop,
   controller failure, or loss of the lease stops participants idempotently;
   SSH keepalives bound failure detection to roughly thirty seconds.

This adds coordination without restoring arbitrary command payloads, mutable
topology flags, UUID state, or a general scheduler. Laguna remains a
single-node recipe. DeepSeek V4 Flash 0731 keeps its worker-first vLLM MP
startup and checkpoint-specific encoding preparation inside its recipe-local
container entrypoint. Its 524,288-token context ceiling uses eager execution
because CUDA-graph profiling causes sustained host-memory reclaim during
startup on the 128 GB nodes.

The DeepSeek recipe persists Triton, B12x, FlashInfer, and vLLM compiler caches
below `/var/cache/deepseek-v4-flash-0731`. Those caches reduce repeated
compilation, but every process start must still allocate and initialize its
volatile KV cache and max-context workspaces. The service is therefore intended
to remain running between requests rather than being started per task.
