# Inference recipes

## Status

This document defines the recipe and catalog contracts. A recipe is a
complete static workload declaration. Artifact preparation is defined in
[Artifacts](artifacts.md), and run-specific behavior is defined in
[Execution](execution.md).

## Responsibilities

A recipe owns static facts:

- exact model revisions and file selections;
- adjacent Containerfile, build context, build arguments, and target platform;
- dependency versions;
- image entrypoint args, host mounts, environment, and devices;
- supported node counts and clustered startup order;
- endpoint and health expectations.

A recipe does not select nodes, locate model replicas, or resolve an image
digest. Runtime-specific flags remain opaque strings; the generic Nix module
does not recreate vLLM or llama.cpp configuration as a large option hierarchy.

## Ownership and layout

Recipes belong to the deployment that currently owns them:

```text
machines/nixos/spark/inference/recipes/
`-- laguna-vllm/
    |-- default.nix
    `-- Containerfile

machines/nixos/sisyphus/inference/recipes/
`-- qwen3-6-heretic-27b/
    |-- default.nix
    `-- Containerfile
```

The generic NixOS module declares typed `my.inference.recipes` options. Each
recipe directory is an ordinary NixOS module, and the deployment imports the
recipes it makes available:

```nix
{
  imports = [./recipes/laguna-vllm];
}
```

Recipe modules define complete values below `my.inference.recipes.<name>`.
NixOS supplies field types, defaults, unknown-option checks, module imports,
and merging. Materially different runtime configuration is a separate recipe.
The attribute key is the canonical recipe name injected into the catalog, so
the recipe value does not repeat it.

If two deployments later use one recipe unchanged, promote it to
`inference/recipes/<name>/` and select it from both configurations. Do not
import a recipe from another machine directory.

## Recipe example

A deployment-local recipe remains self-contained:

```nix
# machines/nixos/spark/inference/recipes/laguna-vllm/default.nix
let
  modelRoot = "/models/target";
in {
  my.inference.recipes.laguna-vllm = {
    models.target = {
      repo = "poolside/Laguna-S-2.1-NVFP4";
      revision = "<commit>";
    };

    image = {
      context = ./.;
      buildArgs.VLLM_VERSION = "0.25.1";
    };

    topology = {
      nodeCounts = [2 4];
      startOrder = "workers-first";
    };

    container = {
      devices = ["nvidia.com/gpu=all"];
      extraOptions = ["--ipc=host"];
      args = [
        modelRoot
        "--served-model-name"
        "poolside/Laguna-S-2.1-NVFP4"
      ];
    };

    endpoint.port = 8000;
  };
}
```

Model attribute keys are recipe-local logical names. Nix normalizes
`models.target` into the catalog model named `target`, and the planner mounts
its complete verified `files/` directory at `/models/target`. A GGUF recipe
selects the required file and passes `/models/target/<file>.gguf` to its
runtime. Recipes never choose host storage paths or direct-file mount behavior.

The adjacent `Containerfile` is implied by `image.context` and contains the
complete image definition. `image.platform` defaults to the platform of the
evaluated NixOS host. Recipe-local variables may remove repetition within the
file, but they are not NixOS options. `schemaVersion`, host networking,
read-only model mounts, and offline Hugging Face behavior are platform
invariants injected by the normalizer and planner. Additional host mounts
default to read-only and may explicitly set `readOnly = false` for a required
persistent runtime cache.

Endpoint ports are recipe-defined in v1; because each node permits one
inference allocation, the node lock prevents two recipes from binding the same
host port. `/health` and a 900-second startup timeout are defaults that recipes
may override.

Endpoint authentication is also recipe policy rather than a generic runtime
schema. A recipe may mount a deployment secret and configure its server to
enforce it. The Spark Laguna recipe deliberately uses unauthenticated HTTP on
the trusted LAN in v1 and remains `autoStart = false` at the instance layer.

## Topology and entrypoints

Omitting `topology` declares a one-node workload. A clustered recipe declares
the node counts it has actually validated and one generic startup order:

- `head-first` starts the API/head node before workers;
- `workers-first` starts workers before the head;
- `parallel` imposes no ordering.

The instance's ordered node list selects concrete hosts. The planner assigns
the first node rank zero and the `head` role, then injects generic values such
as `INFER_ROLE`, `INFER_RANK`, `INFER_WORLD_SIZE`, `INFER_HEAD_ADDRESS`,
`INFER_NODE_ADDRESS`, and `INFER_PORT`.

The image entrypoint translates those values into workload-specific commands.
It may choose vLLM multiprocessing, Ray, llama.cpp, or another runtime without
changing host orchestration. Recipe-local shell scripts may be copied into the
image; recipes do not have arbitrary host-side script hooks.

The model store resolves verified host paths. The image store resolves exact
digests. Recipes know neither storage roots nor registry filesystem layout.

## Catalog contract

Nix normalizes the selected typed recipe options into versioned
`/etc/infer/catalog.json`. The catalog contains complete selected recipes,
image build specifications, model requirements, topology, container
declarations, health checks, and stable recipe and build hashes. It contains no
evaluation timestamps.

Nix is the sole implementation of `recipeHash`. It canonicalizes set-like
values by validating, deduplicating, and sorting them while preserving the
order of semantic sequences such as container args. It computes
`builtins.hashString "sha256" (builtins.toJSON value)` over the canonical recipe
name, schema version, models, `buildHash`, topology, container declaration,
and endpoint. `buildHash` is defined by [Artifacts](artifacts.md).

The Effect runtime validates the full lowercase hexadecimal `recipeHash` but
does not reimplement it. Displays may abbreviate the hash, but persisted
contracts and comparisons use the full value.

`infer` reads this output rather than evaluating Nix at runtime. Recipe and
catalog changes therefore do not rebuild the Effect runtime package.

Instance names, ordered node selections, and boot policy live in the separate
InstanceCatalog defined by [Execution](execution.md). Keeping placement out of
recipes allows one workload declaration to back several predeclared Spark
topologies without recipe overrides.

Nix validates declaration-time facts:

- unique names;
- exact model commits and normalized file selections;
- complete image contexts;
- valid node counts and startup order;
- symbolic model mounts;
- valid endpoint shapes.

Deployment-local ownership avoids a global catalog and a free-form capability
taxonomy. Add a concrete recipe field only when the planner or runtime can
validate and use it. NixOS option types validate author input; a private
normalizer performs cross-field checks and canonicalization; the runtime schema
remains the authoritative decoder for generated JSON.

## Deferred decisions

- Extract a shared recipe only after a second deployment uses it unchanged.
- Add backend-specific host orchestration only after a workload cannot be
  expressed by ordered node services and endpoint readiness.
- Keep instance placement outside the recipe schema.
