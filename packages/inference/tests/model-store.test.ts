import assert from "node:assert/strict"
import { createHash } from "node:crypto"
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync
} from "node:fs"
import { tmpdir } from "node:os"
import * as path from "node:path"
import test from "node:test"
import { FileSystem } from "effect"
import * as NodeServices from "@effect/platform-node/NodeServices"
import { Effect, Result, Fiber, Layer, Schema } from "effect"
import { LocalLock, type LocalLockService } from "../src/adapters/local-lock.js"
import {
  ProcessRunner,
  type ProcessRequest,
  type ProcessRunnerService
} from "../src/adapters/process-runner.js"
import { Inventory } from "../src/domain/contracts.js"
import { CommandError } from "../src/domain/errors.js"
import {
  artifactIdentity,
  normalizeSelection,
  parseModelReference
} from "../src/domain/model-artifact.js"
import {
  archiveModel,
  ensureLocalModel,
  ensureModel,
  modelStatus,
  validateHfDryRun,
  verifyModel
} from "../src/workflows/model-store.js"

const success = { stdout: "", stderr: "" }

const checksumSuccess = (request: ProcessRequest) => {
  assert.deepEqual(request.args.slice(0, 2), ["--binary", "--"])
  const target = request.args.at(-1)!
  const digest = createHash("sha256")
    .update(readFileSync(target))
    .digest("hex")
  return { stdout: `${digest} *${target}\n`, stderr: "" }
}

const fixtureInventory = Schema.decodeUnknownSync(Inventory)(
  JSON.parse(
    readFileSync("tests/fixtures/contracts/v1/inventory.json", "utf8")
  )
)

const makeInventory = (archiveRoot: string, localRoot: string): Inventory => ({
  ...fixtureInventory,
  modelStore: { archiveRoot, localRoot }
})

const makeArtifact = () => {
  const reference = parseModelReference(
    "example/tiny-model@1111111111111111111111111111111111111111"
  )
  const selection = normalizeSelection([], [])
  assert.ok(Result.isSuccess(reference))
  assert.ok(Result.isSuccess(selection))
  return artifactIdentity(
    reference.success.repo,
    reference.success.revision,
    selection.success
  )
}

const completeDownload = (filesPath: string): void => {
  mkdirSync(filesPath, { recursive: true })
  writeFileSync(path.join(filesPath, "config.json"), '{"model":"fixture"}\n')
  writeFileSync(path.join(filesPath, "weights.bin"), Buffer.from("weights\n"))
  mkdirSync(path.join(filesPath, ".cache", "huggingface"), {
    recursive: true
  })
  writeFileSync(path.join(filesPath, ".cache", "huggingface", "state"), "ok")
}

test("model selections normalize to one stable artifact identity", () => {
  const selection = normalizeSelection(
    ["*.json", "weights/*", "*.json"],
    ["*.bin", "*.bin"]
  )
  assert.ok(Result.isSuccess(selection))
  assert.deepEqual(selection.success, {
    include: ["*.json", "weights/*"],
    exclude: ["*.bin"]
  })

  const artifact = artifactIdentity(
    "example/model",
    "1111111111111111111111111111111111111111",
    selection.success
  )
  assert.match(
    artifact.relativePath,
    /^hf\/example\/model\/1{40}\/[0-9a-f]{64}$/
  )
})

test("Hugging Face dry-run output requires a non-empty safe file list", async () => {
  await Effect.runPromise(
    validateHfDryRun('[{"file":"config.json","size":"20.0"}]')
  )

  for (const raw of ["not-json", '[{"file":"../weights.bin"}]']) {
    const invalid = await Effect.runPromise(
      Effect.result(validateHfDryRun(raw))
    )
    assert.ok(Result.isFailure(invalid))
    assert.equal(invalid.failure.code, "hf-dry-run-invalid")
  }

  const empty = await Effect.runPromise(
    Effect.result(validateHfDryRun("[]"))
  )
  assert.ok(Result.isFailure(empty))
  assert.equal(empty.failure.code, "empty-model-selection")
})

test("model status rejects malformed published artifact layouts", async () => {
  const temporary = mkdtempSync(path.join(tmpdir(), "inference-model-status-"))
  const archiveRoot = path.join(temporary, "archive")
  const localRoot = path.join(temporary, "local")
  mkdirSync(archiveRoot)
  mkdirSync(localRoot)

  try {
    const artifact = makeArtifact()
    const artifactRoot = path.join(archiveRoot, artifact.relativePath)
    const filesRoot = path.join(artifactRoot, "files")
    const manifestPath = path.join(artifactRoot, "manifest.json")
    const manifest = readFileSync(
      "tests/fixtures/contracts/v1/model-manifest.json",
      "utf8"
    )
    mkdirSync(filesRoot, { recursive: true })
    writeFileSync(path.join(filesRoot, "config.json"), '{"model":"fixture"}\n')
    writeFileSync(manifestPath, manifest)

    const runner: ProcessRunnerService = {
      foreground: () => Effect.die("unexpected foreground command"),
      probe: () => Effect.die("unexpected probe command"),
      run: () => Effect.die("metadata status must not hash files")
    }
    const runStatus = () =>
      Effect.runPromise(
        modelStatus(makeInventory(archiveRoot, localRoot), artifact).pipe(
          Effect.provide(
            Layer.mergeAll(
              NodeServices.layer,
              Layer.succeed(ProcessRunner, runner)
            )
          )
        )
      )

    assert.equal((await runStatus()).archive.state, "ready")

    const unexpected = path.join(artifactRoot, "unexpected")
    writeFileSync(unexpected, "unexpected")
    const unexpectedLayout = await runStatus()
    assert.equal(unexpectedLayout.archive.state, "invalid")
    assert.ok(
      unexpectedLayout.archive.issues.includes(
        "artifact root contains unexpected entries"
      )
    )
    rmSync(unexpected)

    writeFileSync(manifestPath, '{"schemaVersion":1,"unexpected":true}\n')
    const malformedManifest = await runStatus()
    assert.equal(malformedManifest.archive.state, "invalid")
    assert.ok(malformedManifest.archive.issues.length > 0)

    writeFileSync(manifestPath, manifest)
    writeFileSync(path.join(filesRoot, "config.json"), "short")
    const wrongSize = await runStatus()
    assert.equal(wrongSize.archive.state, "invalid")
    assert.ok(
      wrongSize.archive.issues.includes("size differs for 'config.json'")
    )
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})

test("local model replication validates its declared source node", async () => {
  const temporary = mkdtempSync(path.join(tmpdir(), "inference-model-source-"))
  const archiveRoot = path.join(temporary, "archive")
  const localRoot = path.join(temporary, "local")
  mkdirSync(archiveRoot)
  mkdirSync(localRoot)

  try {
    const artifact = makeArtifact()
    const runner: ProcessRunnerService = {
      foreground: () => Effect.die("unexpected foreground command"),
      probe: () => Effect.die("unexpected probe command"),
      run: () => Effect.die("source validation must not run commands")
    }
    const localLock: LocalLockService = {
      acquire: () => Effect.void
    }
    const runEnsure = (inventory: Inventory, source: string) =>
      Effect.runPromise(
        Effect.result(ensureLocalModel(inventory, artifact, source)).pipe(
          Effect.provide(
            Layer.mergeAll(
              NodeServices.layer,
              Layer.succeed(LocalLock, localLock),
              Layer.succeed(ProcessRunner, runner)
            )
          )
        )
      )
    const inventory = makeInventory(archiveRoot, localRoot)

    const missing = await runEnsure(inventory, "missing-node")
    assert.ok(Result.isFailure(missing))
    assert.equal(missing.failure.code, "model-source-node-not-found")

    const local = await runEnsure(inventory, inventory.localNode)
    assert.ok(Result.isFailure(local))
    assert.equal(local.failure.code, "model-source-is-local")

    const nodes = inventory.nodes.map((node) =>
      node.name === "spark-02"
        ? {
            ...node,
            fabric: { fabric1: node.fabric.fabric1 }
          }
        : node
    )
    const withoutFabric: Inventory = {
      ...inventory,
      nodes: [nodes[0]!, ...nodes.slice(1)]
    }
    const unavailable = await runEnsure(withoutFabric, "spark-02")
    assert.ok(Result.isFailure(unavailable))
    assert.equal(unavailable.failure.code, "model-source-fabric-unavailable")
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})

test("archive can seed its resumable Hugging Face download", async () => {
  const temporary = mkdtempSync(path.join(tmpdir(), "inference-model-seed-"))
  const archiveRoot = path.join(temporary, "archive")
  const localRoot = path.join(temporary, "local")
  const seed = path.join(temporary, "seed")
  mkdirSync(archiveRoot)
  mkdirSync(localRoot)
  completeDownload(seed)

  try {
    const inventory = makeInventory(archiveRoot, localRoot)
    const artifact = makeArtifact()
    const commands: Array<string> = []
    let downloadSawSeed = false
    const runner: ProcessRunnerService = {
      foreground: () =>
        Effect.fail(
          new CommandError({
            code: "unexpected-test-command",
            message: "The model workflow must not run foreground commands"
          })
        ),
      probe: () =>
        Effect.fail(
          new CommandError({
            code: "unexpected-test-probe",
            message: "The model workflow must not probe commands"
          })
        ),
      run: (request: ProcessRequest) => {
        if (request.command === "sha256sum") {
          return Effect.sync(() => checksumSuccess(request))
        }
        if (request.command === "hf" && request.args.includes("--dry-run")) {
          commands.push("hf-dry-run")
          return Effect.succeed({
            stdout: '[{"file":"config.json","size":"20.0"}]',
            stderr: ""
          })
        }
        if (request.command === "rsync") {
          commands.push("rsync")
          assert.equal(request.args.includes("--size-only"), true)
          assert.equal(request.args.includes("--no-owner"), true)
          assert.equal(request.args.includes("--no-group"), true)
          const source = request.args.at(-2)!.replace(/\/$/, "")
          const destination = request.args.at(-1)!.replace(/\/$/, "")
          return Effect.sync(() => {
            cpSync(source, destination, { recursive: true, force: true })
          }).pipe(Effect.as(success))
        }
        if (request.command === "hf") {
          commands.push("hf-download")
          const localDirIndex = request.args.indexOf("--local-dir")
          const filesPath = request.args[localDirIndex + 1]!
          downloadSawSeed = existsSync(path.join(filesPath, "weights.bin"))
          return Effect.succeed(success)
        }
        return Effect.fail(
          new CommandError({
            code: "unexpected-test-command",
            message: `Unexpected command '${request.command}'`
          })
        )
      }
    }
    const run = <A, E>(
      effect: Effect.Effect<A, E, FileSystem.FileSystem | ProcessRunner>
    ) =>
      Effect.runPromise(
        effect.pipe(
          Effect.provide(
            Layer.mergeAll(
              NodeServices.layer,
              Layer.succeed(ProcessRunner, runner)
            )
          )
        )
      )

    const archived = await run(archiveModel(inventory, artifact, seed))
    assert.equal(archived.archive.state, "ready")
    assert.equal(downloadSawSeed, true)
    assert.deepEqual(commands, ["hf-dry-run", "rsync", "hf-download"])
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})

test("archive and ensure resume after interruption and publish atomically", async () => {
  const temporary = mkdtempSync(path.join(tmpdir(), "inference-model-store-"))
  const archiveRoot = path.join(temporary, "archive")
  const localRoot = path.join(temporary, "local")
  mkdirSync(archiveRoot)
  mkdirSync(localRoot)

  try {
    const inventory = makeInventory(archiveRoot, localRoot)
    const artifact = makeArtifact()
    let hfDownloads = 0
    let rsyncCopies = 0
    let localLocks = 0
    let remoteSource: string | undefined
    let downloadStarted!: () => void
    let copyStarted!: () => void
    const downloadStartedPromise = new Promise<void>((resolve) => {
      downloadStarted = resolve
    })
    const copyStartedPromise = new Promise<void>((resolve) => {
      copyStarted = resolve
    })

    const runner: ProcessRunnerService = {
      foreground: () =>
        Effect.fail(
          new CommandError({
            code: "unexpected-test-command",
            message: "The model workflow must not run foreground commands"
          })
        ),
      probe: () =>
        Effect.fail(
          new CommandError({
            code: "unexpected-test-probe",
            message: "The model workflow must not probe commands"
          })
        ),
      run: (request: ProcessRequest) => {
        if (request.command === "sha256sum") {
          return Effect.sync(() => checksumSuccess(request))
        }
        if (request.command === "hf") {
          if (request.args.includes("--dry-run")) {
            return Effect.succeed({
              stdout: '[{"file":"config.json","size":"20.0"}]',
              stderr: ""
            })
          }
          hfDownloads += 1
          const localDirIndex = request.args.indexOf("--local-dir")
          const filesPath = request.args[localDirIndex + 1]!
          if (hfDownloads === 1) {
            return Effect.sync(() => {
              mkdirSync(path.join(filesPath, ".cache", "huggingface"), {
                recursive: true
              })
              writeFileSync(path.join(filesPath, "config.json"), "partial\n")
              downloadStarted()
            }).pipe(Effect.andThen(Effect.never))
          }
          return Effect.sync(() => completeDownload(filesPath)).pipe(
            Effect.as(success)
          )
        }

        if (request.command === "rsync") {
          rsyncCopies += 1
          const sourceArgument = request.args.at(-2)!
          const source = sourceArgument.startsWith("rsync://")
            ? path.join(archiveRoot, artifact.relativePath)
            : sourceArgument.replace(/\/$/, "")
          const destination = request.args.at(-1)!.replace(/\/$/, "")
          if (sourceArgument.startsWith("rsync://")) {
            remoteSource = sourceArgument
            assert.equal(request.args.includes("--contimeout=10"), true)
            assert.equal(request.args.includes("--timeout=300"), true)
          }
          if (rsyncCopies === 1) {
            return Effect.sync(() => {
              mkdirSync(path.join(destination, "files"), { recursive: true })
              cpSync(
                path.join(source, "manifest.json"),
                path.join(destination, "manifest.json")
              )
              cpSync(
                path.join(source, "files", "config.json"),
                path.join(destination, "files", "config.json")
              )
              mkdirSync(path.join(destination, ".rsync-partial"))
              writeFileSync(
                path.join(destination, ".rsync-partial", "weights.bin"),
                "partial"
              )
              copyStarted()
            }).pipe(Effect.andThen(Effect.never))
          }
          return Effect.sync(() => {
            cpSync(source, destination, { recursive: true, force: true })
          }).pipe(Effect.as(success))
        }

        return Effect.fail(
          new CommandError({
            code: "unexpected-test-command",
            message: `Unexpected command '${request.command}'`
          })
        )
      }
    }

    const localLock: LocalLockService = {
      acquire: () =>
        Effect.acquireRelease(
          Effect.sync(() => {
            localLocks += 1
          }),
          () =>
            Effect.sync(() => {
              localLocks -= 1
            })
        ).pipe(Effect.asVoid)
    }

    const layer = Layer.mergeAll(
      NodeServices.layer,
      Layer.succeed(ProcessRunner, runner),
      Layer.succeed(LocalLock, localLock)
    )
    const run = <A, E>(
      effect: Effect.Effect<A, E, FileSystem.FileSystem | LocalLock | ProcessRunner>
    ) =>
      Effect.runPromise(effect.pipe(Effect.provide(layer)))

    await run(
      Effect.gen(function* () {
        const fiber = yield* Effect.forkChild(archiveModel(inventory, artifact))
        yield* Effect.promise(() => downloadStartedPromise)
        yield* Fiber.interrupt(fiber)
      })
    )

    const archiveStaging = path.join(
      archiveRoot,
      ".staging",
      artifact.relativePath
    )
    const archiveLock = path.join(archiveRoot, ".locks", artifact.relativePath)
    assert.equal(existsSync(archiveStaging), true)
    assert.equal(existsSync(archiveLock), false)
    assert.equal(
      existsSync(path.join(archiveRoot, artifact.relativePath)),
      false
    )

    const archived = await run(archiveModel(inventory, artifact))
    assert.equal(archived.archive.state, "ready")
    assert.equal(existsSync(archiveStaging), false)
    assert.equal(
      existsSync(
        path.join(
          archiveRoot,
          artifact.relativePath,
          "files",
          ".cache"
        )
      ),
      false
    )

    await run(archiveModel(inventory, artifact))
    assert.equal(hfDownloads, 2)

    await run(
      Effect.gen(function* () {
        const fiber = yield* Effect.forkChild(ensureModel(inventory, artifact))
        yield* Effect.promise(() => copyStartedPromise)
        yield* Fiber.interrupt(fiber)
      })
    )
    const localStaging = path.join(localRoot, ".staging", artifact.relativePath)
    assert.equal(existsSync(localStaging), true)
    assert.equal(localLocks, 0)

    const ensured = await run(ensureModel(inventory, artifact))
    assert.equal(ensured.local.state, "ready")
    assert.equal(existsSync(localStaging), false)
    assert.equal(localLocks, 0)

    await run(ensureModel(inventory, artifact))
    assert.equal(rsyncCopies, 2)

    const unavailableArchive = path.join(temporary, "archive-unavailable")
    writeFileSync(unavailableArchive, "not a directory")
    const local = await run(
      ensureLocalModel(
        makeInventory(unavailableArchive, localRoot),
        artifact
      )
    )
    assert.equal(local.state, "ready")
    assert.equal(rsyncCopies, 2)

    const replicaRoot = path.join(temporary, "replica")
    mkdirSync(replicaRoot)
    const replicated = await run(
      ensureModel(
        makeInventory(unavailableArchive, replicaRoot),
        artifact,
        "spark-02"
      )
    )
    assert.equal(replicated.source.kind, "node")
    assert.equal(
      replicated.source.kind === "node" ? replicated.source.node : undefined,
      "spark-02"
    )
    assert.equal(replicated.local.state, "ready")
    assert.equal(
      remoteSource,
      `rsync://10.100.0.2:873/models/${artifact.relativePath}/`
    )
    assert.equal(rsyncCopies, 3)

    const verified = await run(verifyModel(inventory, artifact))
    assert.equal(verified.archive.state, "ready")
    assert.equal(verified.local.state, "ready")

    const localConfig = path.join(
      localRoot,
      artifact.relativePath,
      "files",
      "config.json"
    )
    const corrupted = readFileSync(localConfig)
    corrupted[0] = corrupted[0]! ^ 1
    writeFileSync(localConfig, corrupted)

    const inexpensiveStatus = await run(modelStatus(inventory, artifact))
    assert.equal(inexpensiveStatus.local.state, "ready")
    const verification = await run(
      Effect.result(verifyModel(inventory, artifact))
    )
    assert.ok(Result.isFailure(verification))
    assert.equal(verification.failure.code, "model-verification-failed")
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})
