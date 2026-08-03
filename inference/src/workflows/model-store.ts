import { hostname } from "node:os"
import * as path from "node:path"
import { FileSystem } from "@effect/platform"
import { Clock, Console, Effect, Either, ParseResult, Schema } from "effect"
import { LocalLock } from "../adapters/local-lock.js"
import {
  ProcessRunner,
  type ProcessRunnerService
} from "../adapters/process-runner.js"
import {
  ModelManifest as ModelManifestSchema,
  type ArtifactIdentity,
  type ArtifactLocationStatus,
  type Inventory,
  type ModelEnsureResult,
  type ModelManifest,
  type ModelManifestFile,
  type ModelStatus
} from "../domain/contracts.js"
import { CommandError } from "../domain/errors.js"

interface ArtifactPaths {
  readonly final: string
  readonly staging: string
  readonly lock: string
}

interface ValidatedArtifact {
  readonly issues: ReadonlyArray<string>
  readonly manifest?: ModelManifest
}

interface ReplicaSource {
  readonly path: string
  readonly description: string
  readonly remote: boolean
}

const rsyncDaemonPort = 873
const rsyncModule = "models"

const compareAscii = (left: string, right: string): number =>
  left < right ? -1 : left > right ? 1 : 0

const pathsFor = (root: string, artifact: ArtifactIdentity): ArtifactPaths => ({
  final: path.join(root, artifact.relativePath),
  staging: path.join(root, ".staging", artifact.relativePath),
  lock: path.join(root, ".locks", artifact.relativePath)
})

const fsError = (operation: string, target: string): CommandError =>
  new CommandError({
    code: "model-store-io-failed",
    message: `Unable to ${operation} '${target}'`,
    details: { operation, path: target }
  })

const mapFsError = <A, R>(
  effect: Effect.Effect<A, unknown, R>,
  operation: string,
  target: string
): Effect.Effect<A, CommandError, R> =>
  effect.pipe(Effect.mapError(() => fsError(operation, target)))

const ensureRoot = (
  fileSystem: FileSystem.FileSystem,
  root: string
): Effect.Effect<void, CommandError> =>
  mapFsError(fileSystem.stat(root), "access model root", root).pipe(
    Effect.flatMap((info) =>
      info.type === "Directory"
        ? Effect.void
        : Effect.fail(
            new CommandError({
              code: "model-root-unavailable",
              message: `Model root '${root}' is not a directory`,
              details: { root }
            })
          )
    )
  )

const decodeManifest = (
  raw: string
): Either.Either<ModelManifest, ReadonlyArray<string>> => {
  const decoded = Schema.decodeUnknownEither(
    Schema.parseJson(ModelManifestSchema),
    {
      errors: "all",
      onExcessProperty: "error"
    }
  )(raw)
  return Either.isLeft(decoded)
    ? Either.left([
        ParseResult.TreeFormatter.formatErrorSync(decoded.left)
      ])
    : Either.right(decoded.right)
}

const manifestIdentityIssues = (
  manifest: ModelManifest,
  artifact: ArtifactIdentity
): ReadonlyArray<string> => {
  const issues: Array<string> = []
  if (manifest.source !== artifact.source) issues.push("manifest source differs")
  if (manifest.repo !== artifact.repo) issues.push("manifest repository differs")
  if (manifest.revision !== artifact.revision) {
    issues.push("manifest revision differs")
  }
  if (manifest.selectionHash !== artifact.selectionHash) {
    issues.push("manifest selection hash differs")
  }
  if (
    JSON.stringify(manifest.selection) !== JSON.stringify(artifact.selection)
  ) {
    issues.push("manifest selection differs")
  }

  const names = manifest.files.map((file) => file.path)
  const canonical = [...new Set(names)].sort(compareAscii)
  if (
    names.length !== canonical.length ||
    names.some((name, index) => name !== canonical[index])
  ) {
    issues.push("manifest files are not unique and canonically ordered")
  }
  return issues
}

const fileDigest = (
  runner: ProcessRunnerService,
  target: string
): Effect.Effect<string, CommandError> =>
  runner
    .run({ command: "sha256sum", args: ["--binary", "--", target] })
    .pipe(
      Effect.flatMap(({ stdout }) => {
        const match = /^([0-9a-f]{64}) [ *]/.exec(stdout)
        return match === null
          ? Effect.fail(
              new CommandError({
                code: "model-checksum-output-invalid",
                message: `sha256sum returned invalid output for '${target}'`,
                details: { path: target }
              })
            )
          : Effect.succeed(match[1]!)
      })
    )

interface ActualFile {
  readonly path: string
  readonly absolutePath: string
  readonly size: number
}

const listFiles = (
  fileSystem: FileSystem.FileSystem,
  filesRoot: string
): Effect.Effect<ReadonlyArray<ActualFile>, CommandError> =>
  Effect.gen(function* () {
    const entries = yield* mapFsError(
      fileSystem.readDirectory(filesRoot, { recursive: true }),
      "list model files",
      filesRoot
    )
    const files = yield* Effect.forEach(entries, (entry) => {
      const absolutePath = path.join(filesRoot, entry)
      return mapFsError(
        fileSystem.stat(absolutePath),
        "inspect model file",
        absolutePath
      ).pipe(
        Effect.map((info): ActualFile | undefined =>
          info.type === "File"
            ? {
                path: entry.split(path.sep).join("/"),
                absolutePath,
                size: Number(info.size)
              }
            : undefined
        )
      )
    })
    return files
      .filter((file): file is ActualFile => file !== undefined)
      .sort((left, right) => compareAscii(left.path, right.path))
  })

const validateArtifactDirectory = (
  fileSystem: FileSystem.FileSystem,
  runner: ProcessRunnerService,
  directory: string,
  artifact: ArtifactIdentity,
  checksums: boolean
): Effect.Effect<ValidatedArtifact, never> =>
  Effect.gen(function* () {
    const manifestPath = path.join(directory, "manifest.json")
    const rawResult = yield* Effect.either(
      fileSystem.readFileString(manifestPath, "utf8")
    )
    if (Either.isLeft(rawResult)) {
      return { issues: ["manifest.json is missing or unreadable"] }
    }

    const decoded = decodeManifest(rawResult.right)
    if (Either.isLeft(decoded)) return { issues: decoded.left }

    const manifest = decoded.right
    const issues = [...manifestIdentityIssues(manifest, artifact)]
    const rootEntries = yield* Effect.either(fileSystem.readDirectory(directory))
    if (
      Either.isLeft(rootEntries) ||
      JSON.stringify(rootEntries.right.sort(compareAscii)) !==
        JSON.stringify(["files", "manifest.json"])
    ) {
      issues.push("artifact root contains unexpected entries")
    }
    const filesResult = yield* Effect.either(
      listFiles(fileSystem, path.join(directory, "files"))
    )
    if (Either.isLeft(filesResult)) {
      return {
        issues: [...issues, "files directory is missing or unreadable"],
        manifest
      }
    }

    const actualFiles = filesResult.right
    const expectedPaths = manifest.files.map((file) => file.path)
    const actualPaths = actualFiles.map((file) => file.path)
    if (JSON.stringify(expectedPaths) !== JSON.stringify(actualPaths)) {
      issues.push("materialized file set differs from the manifest")
    }

    const actualByPath = new Map(actualFiles.map((file) => [file.path, file]))
    for (const expected of manifest.files) {
      const actual = actualByPath.get(expected.path)
      if (actual === undefined) continue
      if (actual.size !== expected.size) {
        issues.push(`size differs for '${expected.path}'`)
        continue
      }
      if (checksums) {
        const digestResult = yield* Effect.either(
          fileDigest(runner, actual.absolutePath)
        )
        if (Either.isLeft(digestResult)) {
          issues.push(`unable to hash '${expected.path}'`)
        } else if (digestResult.right !== expected.sha256) {
          issues.push(`checksum differs for '${expected.path}'`)
        }
      }
    }
    return { issues, manifest }
  }).pipe(Effect.orDie)

const inspectLocation = (
  fileSystem: FileSystem.FileSystem,
  runner: ProcessRunnerService,
  root: string,
  artifact: ArtifactIdentity,
  checksums: boolean,
  archive: boolean
): Effect.Effect<ArtifactLocationStatus, CommandError> =>
  Effect.gen(function* () {
    yield* ensureRoot(fileSystem, root)
    const paths = pathsFor(root, artifact)
    const finalExists = yield* mapFsError(
      fileSystem.exists(paths.final),
      "inspect artifact",
      paths.final
    )
    if (!finalExists) {
      const [staging, locked] = yield* Effect.all([
        mapFsError(
          fileSystem.exists(paths.staging),
          "inspect staging artifact",
          paths.staging
        ),
        archive
          ? mapFsError(
              fileSystem.exists(paths.lock),
              "inspect archive lock",
              paths.lock
            )
          : Effect.succeed(false)
      ])
      return {
        state: locked ? "locked" : staging ? "staging" : "absent",
        path: paths.final,
        stagingPath: paths.staging,
        issues: []
      }
    }

    const validation = yield* validateArtifactDirectory(
      fileSystem,
      runner,
      paths.final,
      artifact,
      checksums
    )
    const manifest = validation.manifest
    return {
      state: validation.issues.length === 0 ? "ready" : "invalid",
      path: paths.final,
      stagingPath: paths.staging,
      issues: validation.issues,
      ...(manifest === undefined
        ? {}
        : {
            manifest: {
              createdAt: manifest.createdAt,
              fileCount: manifest.files.length,
              totalSize: manifest.files.reduce(
                (total, file) => total + file.size,
                0
              )
            }
          })
    }
  })

export const modelStatus = (
  inventory: Inventory,
  artifact: ArtifactIdentity,
  checksums = false
): Effect.Effect<
  ModelStatus,
  CommandError,
  FileSystem.FileSystem | ProcessRunner
> =>
  Effect.gen(function* () {
    const fileSystem = yield* FileSystem.FileSystem
    const runner = yield* ProcessRunner
    const [archive, local] = yield* Effect.all([
      inspectLocation(
        fileSystem,
        runner,
        inventory.modelStore.archiveRoot,
        artifact,
        checksums,
        true
      ),
      inspectLocation(
        fileSystem,
        runner,
        inventory.modelStore.localRoot,
        artifact,
        checksums,
        false
      )
    ])
    return { schemaVersion: 1, artifact, archive, local }
  })

const requireMutableLocation = (
  location: ArtifactLocationStatus,
  kind: "archive" | "local"
): Effect.Effect<void, CommandError> =>
  location.state === "invalid"
    ? Effect.fail(
        new CommandError({
          code: "published-artifact-invalid",
          message: `The published ${kind} artifact is invalid and will not be replaced`,
          details: { kind, path: location.path, issues: location.issues }
        })
      )
    : Effect.void

const makeParents = (
  fileSystem: FileSystem.FileSystem,
  target: string
): Effect.Effect<void, CommandError> =>
  mapFsError(
    fileSystem.makeDirectory(path.dirname(target), { recursive: true }),
    "create model-store directory",
    path.dirname(target)
  )

const acquireArchiveLock = (
  fileSystem: FileSystem.FileSystem,
  lockPath: string,
  inventory: Inventory,
  artifact: ArtifactIdentity
): Effect.Effect<void, CommandError, import("effect").Scope.Scope> => {
  const acquire = Effect.gen(function* () {
    yield* makeParents(fileSystem, lockPath)
    const created = yield* Effect.either(fileSystem.makeDirectory(lockPath))
    if (Either.isLeft(created)) {
      const exists = yield* fileSystem.exists(lockPath).pipe(
        Effect.orElseSucceed(() => false)
      )
      return yield* Effect.fail(
        new CommandError({
          code: exists ? "archive-locked" : "model-store-io-failed",
          message: exists
            ? `Another writer owns archive lock '${lockPath}'`
            : `Unable to create archive lock '${lockPath}'`,
          details: { path: lockPath }
        })
      )
    }

    const startedAt = new Date(yield* Clock.currentTimeMillis).toISOString()
    const owner = {
      schemaVersion: 1,
      owner: `${hostname()}:${process.pid}`,
      node: inventory.localNode,
      revision: artifact.revision,
      startedAt
    }
    yield* fileSystem
      .writeFileString(
        path.join(lockPath, "owner.json"),
        `${JSON.stringify(owner, null, 2)}\n`
      )
      .pipe(
        Effect.mapError(() => fsError("write archive lock", lockPath)),
        Effect.onError(() =>
          fileSystem.remove(lockPath, { recursive: true, force: true }).pipe(
            Effect.orElseSucceed(() => undefined)
          )
        )
      )
  })
  return Effect.acquireRelease(
    acquire,
    () =>
      fileSystem.remove(lockPath, { recursive: true, force: true }).pipe(
        Effect.orElseSucceed(() => undefined)
      )
  )
}

const buildManifest = (
  fileSystem: FileSystem.FileSystem,
  runner: ProcessRunnerService,
  directory: string,
  artifact: ArtifactIdentity
): Effect.Effect<ModelManifest, CommandError> =>
  Effect.gen(function* () {
    const files = yield* listFiles(fileSystem, path.join(directory, "files"))
    if (files.length === 0) {
      return yield* Effect.fail(
        new CommandError({
          code: "empty-model-selection",
          message: "The model selection did not materialize any files",
          details: { artifact: artifact.relativePath }
        })
      )
    }
    const manifestFiles = yield* Effect.forEach(files, (file) =>
      fileDigest(runner, file.absolutePath).pipe(
        Effect.map(
          (sha256): ModelManifestFile => ({
            path: file.path,
            size: file.size,
            sha256
          })
        )
      )
    )
    const createdAt = new Date(yield* Clock.currentTimeMillis).toISOString()
    return {
      schemaVersion: 1,
      source: artifact.source,
      repo: artifact.repo,
      revision: artifact.revision,
      selection: artifact.selection,
      selectionHash: artifact.selectionHash,
      files: [manifestFiles[0]!, ...manifestFiles.slice(1)],
      createdAt
    }
  })

const syncPath = (
  fileSystem: FileSystem.FileSystem,
  target: string
): Effect.Effect<void, CommandError> =>
  Effect.scoped(
    fileSystem.open(target, { flag: "r" }).pipe(
      Effect.flatMap((file) => file.sync),
      Effect.mapError(() => fsError("synchronize artifact", target))
    )
  )

const writeManifest = (
  fileSystem: FileSystem.FileSystem,
  directory: string,
  manifest: ModelManifest
): Effect.Effect<void, CommandError> =>
  Effect.gen(function* () {
    const target = path.join(directory, "manifest.json")
    const temporary = path.join(directory, ".manifest.json.tmp")
    yield* mapFsError(
      fileSystem.writeFileString(
        temporary,
        `${JSON.stringify(manifest, null, 2)}\n`
      ),
      "write model manifest",
      temporary
    )
    yield* syncPath(fileSystem, temporary)
    yield* mapFsError(
      fileSystem.rename(temporary, target),
      "publish model manifest",
      target
    )
  })

const syncTree = (
  fileSystem: FileSystem.FileSystem,
  root: string
): Effect.Effect<void, CommandError> =>
  Effect.gen(function* () {
    const entries = yield* mapFsError(
      fileSystem.readDirectory(root, { recursive: true }),
      "list staged artifact",
      root
    )
    const targets = entries
      .map((entry) => path.join(root, entry))
      .sort((left, right) => right.length - left.length)
    yield* Effect.forEach(targets, (target) => syncPath(fileSystem, target), {
      concurrency: 1,
      discard: true
    })
    yield* syncPath(fileSystem, root)
  })

const publishStaging = (
  fileSystem: FileSystem.FileSystem,
  paths: ArtifactPaths
): Effect.Effect<void, CommandError> =>
  Effect.gen(function* () {
    const finalExists = yield* mapFsError(
      fileSystem.exists(paths.final),
      "check final artifact",
      paths.final
    )
    if (finalExists) {
      return yield* Effect.fail(
        new CommandError({
          code: "artifact-publication-conflict",
          message: `Final artifact '${paths.final}' already exists`,
          details: { path: paths.final }
        })
      )
    }
    yield* makeParents(fileSystem, paths.final)
    yield* mapFsError(
      fileSystem.rename(paths.staging, paths.final),
      "publish staged artifact",
      paths.final
    )
    yield* syncPath(fileSystem, path.dirname(paths.final))
  })

const validateStaging = (
  fileSystem: FileSystem.FileSystem,
  runner: ProcessRunnerService,
  directory: string,
  artifact: ArtifactIdentity,
  checksums = true
): Effect.Effect<void, CommandError> =>
  validateArtifactDirectory(
    fileSystem,
    runner,
    directory,
    artifact,
    checksums
  ).pipe(
    Effect.flatMap((result) =>
      result.issues.length === 0
        ? Effect.void
        : Effect.fail(
            new CommandError({
              code: "artifact-verification-failed",
              message: `Staged artifact '${directory}' failed verification`,
              details: { path: directory, issues: result.issues }
            })
          )
    )
  )

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

const validateDryRun = (output: string): Effect.Effect<void, CommandError> =>
  Effect.try({
    try: () => JSON.parse(output) as unknown,
    catch: () =>
      new CommandError({
        code: "hf-dry-run-invalid",
        message: "Hugging Face returned an invalid dry-run response"
      })
  }).pipe(
    Effect.flatMap((value) => {
      if (
        !Array.isArray(value) ||
        value.length === 0 ||
        value.some(
          (entry) =>
            typeof entry !== "object" ||
            entry === null ||
            !("file" in entry) ||
            typeof entry.file !== "string" ||
            entry.file.length === 0 ||
            entry.file.startsWith("/") ||
            entry.file.split("/").includes("..")
        )
      ) {
        return Effect.fail(
          new CommandError({
            code: "empty-model-selection",
            message: "The model selection did not resolve to any safe files"
          })
        )
      }
      return Effect.void
    })
  )

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

      yield* Console.error(
        `[models] Checking pinned revision ${artifact.repo}@${artifact.revision}`
      )
      const preflight = yield* runner.run({
        command: "hf",
        args: hfArguments(artifact, ["--dry-run", "--format", "json"]),
        environment: toolEnvironment
      })
      yield* validateDryRun(preflight.stdout)

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
        yield* Console.error(
          `[models] Seeding archive staging for ${artifact.repo}@${artifact.revision}`
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
      yield* Console.error(
        `[models] Reconciling ${artifact.repo}@${artifact.revision} with Hugging Face`
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

      yield* Console.error(
        `[models] Hashing archive files for ${artifact.repo}@${artifact.revision}`
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
        false
      )
      yield* Console.error(
        `[models] Publishing archive artifact ${artifact.repo}@${artifact.revision}`
      )
      yield* syncTree(fileSystem, paths.staging)
      yield* publishStaging(fileSystem, paths)
      return yield* modelStatus(inventory, artifact)
    })
  )

export const ensureLocalModel = (
  inventory: Inventory,
  artifact: ArtifactIdentity,
  sourceNode?: string
): Effect.Effect<
  ArtifactLocationStatus,
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
        false,
        false
      )
      if (before.state === "ready") return before
      yield* requireMutableLocation(before, "local")

      const source: ReplicaSource =
        sourceNode === undefined
          ? yield* Effect.gen(function* () {
              yield* Console.error(
                `[models] Local artifact is ${before.state}; checking archive for ${artifact.repo}@${artifact.revision}`
              )
              const archive = yield* inspectLocation(
                fileSystem,
                runner,
                inventory.modelStore.archiveRoot,
                artifact,
                false,
                true
              )
              if (archive.state !== "ready") {
                return yield* Effect.fail(
                  new CommandError({
                    code: "archive-artifact-not-ready",
                    message: "The requested model is not ready in the archive",
                    details: {
                      path: archive.path,
                      state: archive.state
                    }
                  })
                )
              }
              return {
                path: `${pathsFor(inventory.modelStore.archiveRoot, artifact).final}/`,
                description: "archive",
                remote: false
              }
            })
          : yield* Effect.gen(function* () {
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
                path: `rsync://${node.fabric.fabric0}:${rsyncDaemonPort}/${rsyncModule}/${artifact.relativePath}/`,
                description: `node '${node.name}' over fabric0`,
                remote: true
              }
            })

      const localPaths = pathsFor(inventory.modelStore.localRoot, artifact)
      yield* makeParents(fileSystem, localPaths.lock)
      yield* localLock.acquire(localPaths.lock)

      const afterLock = yield* inspectLocation(
        fileSystem,
        runner,
        inventory.modelStore.localRoot,
        artifact,
        false,
        false
      )
      if (afterLock.state === "ready") {
        return afterLock
      }
      yield* requireMutableLocation(afterLock, "local")

      yield* mapFsError(
        fileSystem.makeDirectory(localPaths.staging, { recursive: true }),
        "create local staging directory",
        localPaths.staging
      )
      yield* Console.error(
        `[models] Copying ${artifact.repo}@${artifact.revision} from ${source.description} to local staging`
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
          ...(source.remote ? ["--contimeout=10", "--timeout=300"] : []),
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
      yield* Console.error(
        `[models] Verifying local replica ${artifact.repo}@${artifact.revision}`
      )
      yield* validateStaging(fileSystem, runner, localPaths.staging, artifact)
      yield* Console.error(
        `[models] Publishing local replica ${artifact.repo}@${artifact.revision}`
      )
      yield* syncTree(fileSystem, localPaths.staging)
      yield* publishStaging(fileSystem, localPaths)
      return yield* inspectLocation(
        fileSystem,
        runner,
        inventory.modelStore.localRoot,
        artifact,
        false,
        false
      )
    })
  )

export const ensureModel = (
  inventory: Inventory,
  artifact: ArtifactIdentity,
  sourceNode?: string
): Effect.Effect<
  ModelEnsureResult,
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
  modelStatus(inventory, artifact, true).pipe(
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
