# Model and image artifacts

## Status

This document defines the contracts for model archives, local model
replicas, OCI image publication, and artifact preparation. Recipe declarations
are defined in [Recipes](recipes.md); run-time orchestration is defined in
[Execution](execution.md).

## Invariants

- Final artifact locations contain only complete, verified artifacts.
- Artifact identities include every input that can change their contents.
- Publication never mutates an existing identity.
- `ensure` is idempotent and resumable and does not access Hugging Face
  implicitly.
- Inference reads models only from local NVMe and runs images by exact digest.
- Preparation succeeds only when every requested destination is ready.

## Model store

### Layout and identity

Store each selected model revision as one immutable, materialized artifact:

```text
<root>/
|-- .locks/
|-- .staging/hf/<org>/<repo>/<commit>/<selection-hash>/
`-- hf/<org>/<repo>/<commit>/<selection-hash>/
    |-- manifest.json
    `-- files/
        |-- config.json
        `-- model-00001-of-00008.safetensors
```

The initial roots are:

```text
archive: /mnt/nas/unas/ai/models
local:   /srv/models
```

The artifact identity is its source kind, repository, exact commit, and
normalized file selection. Omitting a selection means the complete revision;
recipes may otherwise declare include and exclude patterns for repositories
that contain several quantizations. The selection hash prevents two subsets of
one commit from sharing a readiness path.

Normalization validates relative patterns, removes duplicates, sorts include
and exclude lists, and hashes their canonical JSON with SHA-256. The full hash
is the path identity; displays may abbreviate it. The manifest records both the
normalized selection and the exact files that Hugging Face resolved from it.

The final artifact directory exists if and only if its manifest and files are
complete and verified. The planner mounts its complete `files/` directory at
the recipe-local `/models/<name>` path. Archive and local roots use the same
relative path, so replication copies a self-contained tree without translating
layouts.

This is deliberately a materialized artifact layout rather than Hugging Face's
native cache layout. The native `blobs`, `refs`, and `snapshots` structure is
useful for a downloader-managed cache, but it exposes symlink and garbage
collection details to the rest of the system. The inference contract needs an
ordinary, independently verifiable directory that can be copied and atomically
published as one unit.

### Manifest and publication

`ModelManifest` is versioned and records:

- repository and exact commit;
- normalized include and exclude selection;
- selected relative files, sizes, and SHA-256 checksums;
- creation time.

Before mutation, `hf` dry-run output validates the selection and estimates the
required space. `hf download` then materializes the selected revision below
`.staging`; its local metadata makes an interrupted download resumable. After
the files pass verification, the writer removes downloader metadata, writes
the manifest, synchronizes the staged tree, and atomically renames the artifact
into its final path.

Cluster replication copies the final artifact into the destination's matching
`.staging` path, verifies it, and atomically renames it. The manifest is the
integrity contract, but it does not need to describe a Hugging Face blob closure
or generate an rsync file list.

Both control nodes may archive so Sisyphus remains independent of the Sparks.
Archive writers serialize each artifact with an atomic lock directory under:

```text
<archive>/.locks/hf/<org>/<repo>/<commit>/<selection-hash>/
```

The lock records its owner, node, revision, and start time. There is no
automatic expiry because a valid download may run for hours. After confirming
the recorded owner is inactive, an administrator may explicitly break a stale
lock. A replacement writer may then resume the existing staging download.

Local materialization uses a kernel `flock` on the corresponding path below
the local `.locks` root. Concurrent ensures collapse into one transfer, and the
lock releases automatically after interruption.

### Model interface

```text
models archive ORG/REPO@COMMIT [--include PATTERN] [--exclude PATTERN] [--seed ABSOLUTE-DIRECTORY]
models ensure ORG/REPO@COMMIT [--include PATTERN] [--exclude PATTERN] [--source NODE]
models status ORG/REPO@COMMIT [--include PATTERN] [--exclude PATTERN]
models verify ORG/REPO@COMMIT [--include PATTERN] [--exclude PATTERN]
```

Here, `[selection]` means the same optional repeated `--include` and
`--exclude` flags. Omitting them selects the complete revision. Every read
command supports `--json`.

`status` checks publication metadata and reports archive and replica readiness
without hashing every byte. `verify` performs the expensive full checksum
audit. `ensure` also verifies every new copy before publication.

`archive --seed` is an acquisition optimization for an existing Hugging Face
local directory. Under the normal archive lock, it rsyncs that directory into
the resumable staging area before running the same pinned `hf download`,
manifest, verification, and atomic publication workflow. It does not create a
second import format or bypass the archive contract.

The seed is trusted input. The pinned download reconciles repository structure
and selection, but `--seed` does not force every existing byte to be fetched
again solely to prove it against upstream. The generated manifest becomes the
integrity authority for all replicas made from that archive artifact.

`ensure` never downloads from the internet. Without `--source`, it is restricted
to the deployment control node and materializes from the archive. With
`--source NODE`, any deployment node may pull the exact published artifact from
that declared node's read-only rsync module on `fabric0`. A ready local artifact
returns without contacting either source.

For Sisyphus or a single Spark:

```text
NAS artifact -> local staging -> verify -> atomic rename
```

The clustered instance workflow extends the same primitive. For several
Sparks:

1. Select an existing verified replica as the seed when possible.
2. If none exists, stage one selected Spark from the NAS.
3. Have each missing node pull sequentially from the seed's read-only rsync
   daemon on `fabric0`.
4. Use `--whole-file` and a partial directory against the exact artifact path.
5. Verify and atomically publish every requested replica before returning
   success.

V1 permits one outgoing model stream per seed and does not use `fabric1` or a
tree topology. Transfer parallelism is tuning, not part of correctness.

Every Spark exposes its local model root as the read-only `models` rsync module,
bound only to its `fabric0` address on port 873. The daemon runs with enough
access to read published artifacts, accepts no writes, and permits one transfer
at a time. Receivers use whole-file mode, resumable partials, connection and I/O
timeouts, full manifest verification, and the same atomic local publication
path as archive-sourced copies.

Managed llama.cpp recipes pass a verified local GGUF with `-m`. Although
llama.cpp supports `-hf`, that option uses a separate `LLAMA_CACHE` and would
couple model acquisition back into inference.

References:

- [Hugging Face CLI](https://huggingface.co/docs/huggingface_hub/en/guides/cli)
- [Hugging Face file downloads](https://huggingface.co/docs/huggingface_hub/package_reference/file_download)
- [llama.cpp CLI options](https://github.com/ggml-org/llama.cpp/blob/master/tools/cli/README.md)

## Image store

### Registry and identity

Each deployment runs a minimal OCI registry using local filesystem storage:

- Spark: `10.100.0.1:5000`, bound only to `spark-01`'s trusted fabric address.
- Sisyphus: `127.0.0.1:5000`, bound only to loopback on `sisyphus`.

Both store data in `/var/lib/infer/registry`. V1 uses plain HTTP inside these
restricted boundaries, disables deletion, keeps all published images, and
performs no garbage collection. The registry is a rebuildable cache and is not
backed up. V1 needs no registry UI, database, Redis, replication, or high
availability.

Two identifiers remain distinct:

- **Build hash:** a deterministic fingerprint of the Containerfile, context,
  build arguments, and target platform. It answers whether the same build has
  already been published.
- **Image digest:** the OCI fingerprint of the exact produced image. It is the
  identity passed to Podman and recorded on the service container.

Nix is the sole implementation of `buildHash`. It computes
`builtins.hashString "sha256" (builtins.toJSON value)` over the schema version,
target platform, normalized build arguments, and Nix store paths for the
Containerfile and complete build context. Those store paths make their file
contents part of the identity. The runtime validates the full lowercase
hexadecimal value but does not reimplement the hash. Displays may abbreviate
it; registry tags and comparisons do not.

The build hash becomes a write-once registry tag:

```text
<registry>/infer/<recipe>:build-<hash>
```

The registry tag is the publication index; there is no separate build-hash to
digest database. Skopeo resolves the tag to its manifest digest without pulling
the image.

### Image preparation

Image preparation is an internal instance-service workflow. It is not a
separate lifecycle for operators to coordinate before `systemctl start`.
Skopeo and Podman remain available for low-level inspection and repair.

Image preparation is:

1. Query the build-hash tag and resolve its digest when present.
2. If absent, acquire a build-hash lock on the control node and check again.
3. Build once on the deployment control node and push under that tag.
4. Capture the pushed manifest digest.
5. Pull missing images on selected nodes by exact digest.
6. Block until every selected node reports that digest locally.

Only the control node may build a missing tag. A worker restores an existing
digest but fails clearly if the control node has not published that build yet.

The workflow never overwrites an existing build-hash tag. Failed uploads are
safe to retry because the manifest tag is published after its blobs. The
running container label records the exact digest used by the service
invocation.

A missing manifest is distinct from an unavailable registry. Only a confirmed
missing tag permits a build; connection or inspection failures stop preparation
instead of risking replacement of an existing write-once tag.

Sisyphus uses the same publication contract even though builder, registry, and
consumer are one host. This avoids a second local-image identity backend.

Registry unavailability blocks instance preparation, including a restart with
an image already cached by Podman. This conservative behavior avoids running a
local image whose build tag can no longer be resolved. Recipes pin base images
by digest and dependency versions wherever practical; v1 does not mirror
external package repositories.

References:

- [OCI Distribution API](https://distribution.github.io/distribution/spec/api/)
- [Skopeo](https://github.com/containers/skopeo)
- [Podman push](https://docs.podman.io/en/stable/markdown/podman-push.1.html)
- [Podman pull](https://docs.podman.io/en/stable/markdown/podman-pull.1.html)

## Deferred decisions

- Add model eviction or registry garbage collection only after observing disk
  pressure.
- Tune model-copy concurrency or use `fabric1` only after measuring the simple
  transfer path.
- Add heterogeneous image builders only if a control node cannot build one of
  its deployment's selected recipes.
- Add registry authentication or TLS if an endpoint leaves its trusted network
  boundary.
