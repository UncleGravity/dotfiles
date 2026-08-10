import * as path from "node:path"
import { FileSystem } from "effect"
import { Effect, Result, Schema } from "effect"
import { LocalLock } from "../adapters/local-lock.js"
import {
  ProcessRunner,
  type ProcessRunnerService
} from "../adapters/process-runner.js"
import {
  RelativePath,
  type ArtifactIdentity,
  type ArtifactLocationStatus,
  type Inventory,
  type ModelStatus,
  type ReadyArtifactLocation,
  type ReadyModelEnsureResult
} from "../domain/contracts.js"
import { CommandError } from "../domain/errors.js"
import { formatParseError } from "../domain/json-contract.js"
import { emitProgress } from "../observability/progress.js"
import {
  acquireArchiveLock,
  buildManifest,
  fsError,
  inspectLocation,
  makeParents,
  mapFsError,
  modelStatus,
  pathsFor,
  publishStaging,
  requireMutableLocation,
  requireReadyLocation,
  syncTree,
  validateStaging,
  writeManifest
} from "./model-store/artifact-store.js"

export { modelStatus }

type ReplicaSource =
  | {
      readonly kind: "archive"
      readonly path: string
      readonly description: string
    }
  | {
      readonly kind: "node"
      readonly path: string
      readonly description: string
    }
const rsyncDaemonPort = 873
const rsyncModule = "models"

const phase = (
  artifact: ArtifactIdentity,
  operation: string,
  state: "started" | "completed" | "failed" | "warning",
  message: string,
  attributes?: Readonly<Record<string, unknown>>
): Effect.Effect<void> =>
  emitProgress({
    kind: "lifecycle",
    scope: "model",
    operation,
    state,
    message,
    model: `${artifact.repo}@${artifact.revision}`,
    ...(attributes === undefined ? {} : { attributes })
  })

const hfArguments = (
  artifact: ArtifactIdentity,
  extra: ReadonlyArray<string>
): ReadonlyArray<string> => [
  "download",
  artifact.repo,
  "--revision",
  artifact.revision,
  ...artifact.selection.include.flatMap((pattern) => ["--include", pattern]),
  ...artifact.selection.exclude.flatMap((pattern) => ["--exclude", pattern]),
  ...extra
]

const toolEnvironment = {
  HF_HUB_DISABLE_PROGRESS_BARS: "1",
  HF_HUB_DISABLE_TELEMETRY: "1",
  HF_HUB_DISABLE_UPDATE_CHECK: "1"
}

const HfDryRunResponse = Schema.Array(
  Schema.Struct({ file: RelativePath })
)

export const validateHfDryRun = (
  output: string
): Effect.Effect<void, CommandError> =>
  Effect.gen(function* () {
    const decoded = Schema.decodeUnknownResult(
      Schema.fromJsonString(HfDryRunResponse),
      { errors: "all" }
    )(output)
    if (Result.isFailure(decoded)) {
      return yield* Effect.fail(
        new CommandError({
          code: "hf-dry-run-invalid",
          message: "Hugging Face returned an invalid dry-run response",
          details: { issues: formatParseError(decoded.failure) }
        })
      )
    }
    if (decoded.success.length === 0) {
      return yield* Effect.fail(
        new CommandError({
          code: "empty-model-selection",
          message: "The model selection did not resolve to any files"
        })
      )
    }
  })

const validateArchiveSeed = (
  fileSystem: FileSystem.FileSystem,
  seed: string
): Effect.Effect<string, CommandError> => {
  if (!path.isAbsolute(seed)) {
    return Effect.fail(
      new CommandError({
        code: "archive-seed-invalid",
        message: "The archive seed must be an absolute directory path",
        details: { path: seed }
      })
    )
  }

  return fileSystem.stat(seed).pipe(
    Effect.mapError(
      () =>
        new CommandError({
          code: "archive-seed-invalid",
          message: `Unable to access archive seed '${seed}'`,
          details: { path: seed }
        })
    ),
    Effect.flatMap((info) =>
      info.type === "Directory"
        ? Effect.succeed(path.normalize(seed))
        : Effect.fail(
            new CommandError({
              code: "archive-seed-invalid",
              message: `Archive seed '${seed}' is not a directory`,
              details: { path: seed }
            })
          )
    )
  )
}

const resolveReplicaSource = (
  fileSystem: FileSystem.FileSystem,
  runner: ProcessRunnerService,
  inventory: Inventory,
  artifact: ArtifactIdentity,
  localState: ArtifactLocationStatus["state"],
  sourceNode?: string
): Effect.Effect<ReplicaSource, CommandError> =>
  sourceNode === undefined
    ? Effect.gen(function* () {
        yield* phase(
          artifact,
          "locate-source",
          "started",
          `Local artifact is ${localState}; checking archive for ${artifact.repo}@${artifact.revision}`
        )
        const archive = yield* inspectLocation(
          fileSystem,
          runner,
          inventory.modelStore.archiveRoot,
          artifact,
          { kind: "archive", verification: "metadata" }
        )
        if (archive.state !== "ready") {
          return yield* Effect.fail(
            new CommandError({
              code: "archive-artifact-not-ready",
              message: "The requested model is not ready in the archive",
              details: { path: archive.path, state: archive.state }
            })
          )
        }
        return {
          kind: "archive",
          path: `${pathsFor(inventory.modelStore.archiveRoot, artifact).final}/`,
          description: "archive"
        }
      })
    : Effect.gen(function* () {
        const node = inventory.nodes.find(
          (candidate) => candidate.name === sourceNode
        )
        if (node === undefined) {
          return yield* Effect.fail(
            new CommandError({
              code: "model-source-node-not-found",
              message: `Model source node '${sourceNode}' is not in this deployment`,
              details: { sourceNode }
            })
          )
        }
        if (node.name === inventory.localNode) {
          return yield* Effect.fail(
            new CommandError({
              code: "model-source-is-local",
              message: `Model source node '${sourceNode}' is the local node`,
              details: { sourceNode }
            })
          )
        }
        if (node.fabric.fabric0 === undefined) {
          return yield* Effect.fail(
            new CommandError({
              code: "model-source-fabric-unavailable",
              message: `Model source node '${sourceNode}' has no fabric0 address`,
              details: { sourceNode }
            })
          )
        }
        return {
          kind: "node",
          path: `rsync://${node.fabric.fabric0}:${rsyncDaemonPort}/${rsyncModule}/${artifact.relativePath}/`,
          description: `node '${node.name}' over fabric0`
        }
      })

export const archiveModel = (
  inventory: Inventory,
  artifact: ArtifactIdentity,
  seed?: string
): Effect.Effect<
  ModelStatus,
  CommandError,
  FileSystem.FileSystem | ProcessRunner
> =>
  Effect.scoped(
    Effect.gen(function* () {
      const fileSystem = yield* FileSystem.FileSystem
      const runner = yield* ProcessRunner
      const before = yield* modelStatus(inventory, artifact)
      if (before.archive.state === "ready") return before
      yield* requireMutableLocation(before.archive, "archive")
      const validatedSeed =
        seed === undefined
          ? undefined
          : yield* validateArchiveSeed(fileSystem, seed)

      yield* phase(
        artifact,
        "validate-revision",
        "started",
        `Checking pinned revision ${artifact.repo}@${artifact.revision}`
      )
      const preflight = yield* runner.run({
        command: "hf",
        args: hfArguments(artifact, ["--dry-run", "--format", "json"]),
        environment: toolEnvironment
      })
      yield* validateHfDryRun(preflight.stdout)

      const paths = pathsFor(inventory.modelStore.archiveRoot, artifact)
      yield* acquireArchiveLock(fileSystem, paths.lock, inventory, artifact)

      const finalExists = yield* fileSystem.exists(paths.final).pipe(
        Effect.mapError(() => fsError("inspect archive artifact", paths.final))
      )
      if (finalExists) {
        const current = yield* modelStatus(inventory, artifact)
        if (current.archive.state === "ready") return current
        yield* requireMutableLocation(current.archive, "archive")
      }

      const filesPath = path.join(paths.staging, "files")
      yield* mapFsError(
        fileSystem.makeDirectory(filesPath, { recursive: true }),
        "create archive staging directory",
        filesPath
      )
      if (validatedSeed !== undefined) {
        yield* phase(
          artifact,
          "seed-archive",
          "started",
          `Seeding archive staging for ${artifact.repo}@${artifact.revision}`
        )
        yield* runner.run({
          command: "rsync",
          args: [
            "--archive",
            "--size-only",
            "--no-owner",
            "--no-group",
            "--whole-file",
            "--partial-dir=.rsync-partial",
            `${validatedSeed}/`,
            `${filesPath}/`
          ]
        })
        yield* fileSystem
          .remove(path.join(filesPath, ".rsync-partial"), {
            recursive: true,
            force: true
          })
          .pipe(
            Effect.mapError(() =>
              fsError("remove rsync partial directory", filesPath)
            )
          )
      }
      yield* phase(
        artifact,
        "download-archive",
        "started",
        `Reconciling ${artifact.repo}@${artifact.revision} with Hugging Face`
      )
      yield* runner.run({
        command: "hf",
        args: hfArguments(artifact, ["--local-dir", filesPath]),
        environment: toolEnvironment
      })
      yield* fileSystem
        .remove(path.join(filesPath, ".cache"), {
          recursive: true,
          force: true
        })
        .pipe(
          Effect.mapError(() =>
            fsError("remove Hugging Face metadata", filesPath)
          )
        )

      yield* phase(
        artifact,
        "hash-archive",
        "started",
        `Hashing archive files for ${artifact.repo}@${artifact.revision}`
      )
      const manifest = yield* buildManifest(
        fileSystem,
        runner,
        paths.staging,
        artifact
      )
      yield* writeManifest(fileSystem, paths.staging, manifest)
      yield* validateStaging(
        fileSystem,
        runner,
        paths.staging,
        artifact,
        "metadata"
      )
      yield* phase(
        artifact,
        "publish-archive",
        "started",
        `Publishing archive artifact ${artifact.repo}@${artifact.revision}`
      )
      yield* syncTree(fileSystem, paths.staging)
      yield* publishStaging(fileSystem, paths)
      yield* phase(
        artifact,
        "publish-archive",
        "completed",
        `Archive artifact ${artifact.repo}@${artifact.revision} is ready`
      )
      return yield* modelStatus(inventory, artifact)
    })
  ).pipe(
    Effect.withSpan("inference.archive-model", {
      attributes: { "inference.model": `${artifact.repo}@${artifact.revision}` }
    })
  )

export const ensureLocalModel = (
  inventory: Inventory,
  artifact: ArtifactIdentity,
  sourceNode?: string
): Effect.Effect<
  ReadyArtifactLocation,
  CommandError,
  FileSystem.FileSystem | LocalLock | ProcessRunner
> =>
  Effect.scoped(
    Effect.gen(function* () {
      const fileSystem = yield* FileSystem.FileSystem
      const localLock = yield* LocalLock
      const runner = yield* ProcessRunner
      const before = yield* inspectLocation(
        fileSystem,
        runner,
        inventory.modelStore.localRoot,
        artifact,
        { kind: "local", verification: "metadata" }
      )
      if (before.state === "ready") return yield* requireReadyLocation(before)
      yield* requireMutableLocation(before, "local")

      const source = yield* resolveReplicaSource(
        fileSystem,
        runner,
        inventory,
        artifact,
        before.state,
        sourceNode
      )

      const localPaths = pathsFor(inventory.modelStore.localRoot, artifact)
      yield* makeParents(fileSystem, localPaths.lock)
      yield* localLock.acquire(localPaths.lock)

      const afterLock = yield* inspectLocation(
        fileSystem,
        runner,
        inventory.modelStore.localRoot,
        artifact,
        { kind: "local", verification: "metadata" }
      )
      if (afterLock.state === "ready") {
        return yield* requireReadyLocation(afterLock)
      }
      yield* requireMutableLocation(afterLock, "local")

      yield* mapFsError(
        fileSystem.makeDirectory(localPaths.staging, { recursive: true }),
        "create local staging directory",
        localPaths.staging
      )
      yield* phase(
        artifact,
        "copy-local",
        "started",
        `Copying ${artifact.repo}@${artifact.revision} from ${source.description} to local staging`,
        { source: source.description }
      )
      yield* runner.run({
        command: "rsync",
        args: [
          "--archive",
          "--no-owner",
          "--no-group",
          "--whole-file",
          "--partial-dir=.rsync-partial",
          "--delete",
          ...(source.kind === "node"
            ? ["--contimeout=10", "--timeout=300"]
            : []),
          source.path,
          `${localPaths.staging}/`
        ]
      })
      yield* fileSystem
        .remove(path.join(localPaths.staging, ".rsync-partial"), {
          recursive: true,
          force: true
        })
        .pipe(
          Effect.mapError(() =>
            fsError("remove rsync partial directory", localPaths.staging)
          )
        )
      yield* phase(
        artifact,
        "verify-local",
        "started",
        `Verifying local replica ${artifact.repo}@${artifact.revision}`
      )
      yield* validateStaging(
        fileSystem,
        runner,
        localPaths.staging,
        artifact,
        "checksums"
      )
      yield* phase(
        artifact,
        "publish-local",
        "started",
        `Publishing local replica ${artifact.repo}@${artifact.revision}`
      )
      yield* syncTree(fileSystem, localPaths.staging)
      yield* publishStaging(fileSystem, localPaths)
      const published = yield* inspectLocation(
        fileSystem,
        runner,
        inventory.modelStore.localRoot,
        artifact,
        { kind: "local", verification: "metadata" }
      )
      const ready = yield* requireReadyLocation(published)
      yield* phase(
        artifact,
        "publish-local",
        "completed",
        `Local replica ${artifact.repo}@${artifact.revision} is ready`
      )
      return ready
    })
  ).pipe(
    Effect.withSpan("inference.ensure-local-model", {
      attributes: { "inference.model": `${artifact.repo}@${artifact.revision}` }
    })
  )

export const ensureModel = (
  inventory: Inventory,
  artifact: ArtifactIdentity,
  sourceNode?: string
): Effect.Effect<
  ReadyModelEnsureResult,
  CommandError,
  FileSystem.FileSystem | LocalLock | ProcessRunner
> =>
  ensureLocalModel(inventory, artifact, sourceNode).pipe(
    Effect.map((local) => ({
      schemaVersion: 1 as const,
      artifact,
      source:
        sourceNode === undefined
          ? ({ kind: "archive" } as const)
          : ({ kind: "node", node: sourceNode } as const),
      local
    }))
  )

export const verifyModel = (
  inventory: Inventory,
  artifact: ArtifactIdentity
): Effect.Effect<
  ModelStatus,
  CommandError,
  FileSystem.FileSystem | ProcessRunner
> =>
  modelStatus(inventory, artifact, "checksums").pipe(
    Effect.flatMap((status) =>
      status.archive.state === "ready" && status.local.state === "ready"
        ? Effect.succeed(status)
        : Effect.fail(
            new CommandError({
              code: "model-verification-failed",
              message: "The model is not verified in both archive and local storage",
              details: {
                archive: status.archive,
                local: status.local
              }
            })
          )
    )
  )
