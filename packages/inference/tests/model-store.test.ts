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
import { FileSystem } from "@effect/platform"
import { NodeContext } from "@effect/platform-node"
import { Effect, Either, Fiber, Layer, Schema } from "effect"
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
  assert.ok(Either.isRight(reference))
  assert.ok(Either.isRight(selection))
  return artifactIdentity(
    reference.right.repo,
    reference.right.revision,
    selection.right
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
  assert.ok(Either.isRight(selection))
  assert.deepEqual(selection.right, {
    include: ["*.json", "weights/*"],
    exclude: ["*.bin"]
  })

  const artifact = artifactIdentity(
    "example/model",
    "1111111111111111111111111111111111111111",
    selection.right
  )
  assert.match(
    artifact.relativePath,
    /^hf\/example\/model\/1{40}\/[0-9a-f]{64}$/
  )
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
              NodeContext.layer,
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

    const runner: ProcessRunnerService = {
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
            }).pipe(Effect.zipRight(Effect.never))
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
            }).pipe(Effect.zipRight(Effect.never))
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
      NodeContext.layer,
      Layer.succeed(ProcessRunner, runner),
      Layer.succeed(LocalLock, localLock)
    )
    const run = <A, E>(
      effect: Effect.Effect<A, E, FileSystem.FileSystem | LocalLock | ProcessRunner>
    ) =>
      Effect.runPromise(effect.pipe(Effect.provide(layer)))

    await run(
      Effect.gen(function* () {
        const fiber = yield* Effect.fork(archiveModel(inventory, artifact))
        yield* Effect.sleep("50 millis")
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
        const fiber = yield* Effect.fork(ensureModel(inventory, artifact))
        yield* Effect.sleep("50 millis")
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
      Effect.either(verifyModel(inventory, artifact))
    )
    assert.ok(Either.isLeft(verification))
    assert.equal(verification.left.code, "model-verification-failed")
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})
