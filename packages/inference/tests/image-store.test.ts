import assert from "node:assert/strict"
import { mkdtempSync, readFileSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import * as path from "node:path"
import test from "node:test"
import { FileSystem } from "@effect/platform"
import { NodeContext } from "@effect/platform-node"
import { Effect, Either, Fiber, Layer, Schema } from "effect"
import { LocalLock, type LocalLockService } from "../src/adapters/local-lock.js"
import {
  ProcessRunner,
  type ProcessOutcome,
  type ProcessRequest,
  type ProcessRunnerService
} from "../src/adapters/process-runner.js"
import { Catalog, Inventory } from "../src/domain/contracts.js"
import { CommandError } from "../src/domain/errors.js"
import { ensureImage, imageStatus } from "../src/workflows/image-store.js"

const catalog = Schema.decodeUnknownSync(Catalog)(
  JSON.parse(readFileSync("tests/fixtures/contracts/v1/catalog.json", "utf8"))
)
const baseInventory = Schema.decodeUnknownSync(Inventory)(
  JSON.parse(readFileSync("tests/fixtures/contracts/v1/inventory.json", "utf8"))
)
const digest = `sha256:${"d".repeat(64)}`

const outcome = (
  exitCode: number,
  stdout = "",
  stderr = ""
): ProcessOutcome => ({ stdout, stderr, exitCode, signal: null })

test("image ensure builds once and restores the immutable digest", async () => {
  const temporary = mkdtempSync(path.join(tmpdir(), "inference-image-store-"))
  try {
    const inventory: Inventory = {
      ...baseInventory,
      modelStore: {
        ...baseInventory.modelStore,
        localRoot: path.join(temporary, "models")
      }
    }
    let registryDigest: string | undefined
    let localReady = false
    let builds = 0
    let pushes = 0
    let pulls = 0
    let locks = 0
    let interruptFirstBuild = true
    const requests: Array<ProcessRequest> = []
    let buildStarted!: () => void
    const buildStartedPromise = new Promise<void>((resolve) => {
      buildStarted = resolve
    })

    const runner: ProcessRunnerService = {
      foreground: () =>
        Effect.fail(
          new CommandError({
            code: "unexpected-test-command",
            message: "The image workflow must not run foreground commands"
          })
        ),
      probe: (request) =>
        Effect.sync(() => {
          requests.push(request)
          if (request.command === "skopeo") {
            return registryDigest === undefined
              ? outcome(1, "", "manifest unknown")
              : outcome(0, `${registryDigest}\n`)
          }
          if (
            request.command === "podman" &&
            request.args[0] === "image" &&
            request.args[1] === "exists"
          ) {
            return outcome(localReady ? 0 : 1)
          }
          throw new Error(`Unexpected probe '${request.command}'`)
        }),
      run: (request) => {
        if (
          request.command === "podman" &&
          request.args[0] === "build" &&
          interruptFirstBuild
        ) {
          interruptFirstBuild = false
          return Effect.sync(() => {
            requests.push(request)
            buildStarted()
          }).pipe(Effect.zipRight(Effect.never))
        }
        return Effect.sync(() => {
          requests.push(request)
          if (request.command !== "podman") {
            throw new Error(`Unexpected command '${request.command}'`)
          }
          if (request.args[0] === "build") builds += 1
          else if (request.args[0] === "push") {
            pushes += 1
            registryDigest = digest
          } else if (request.args[0] === "pull") {
            pulls += 1
            localReady = true
          } else {
            throw new Error(`Unexpected Podman operation '${request.args[0]}'`)
          }
          return { stdout: "", stderr: "" }
        }).pipe(
          Effect.mapError(
            () =>
              new CommandError({
                code: "test-command-failed",
                message: "The fake image command failed"
              })
          )
        )
      }
    }
    const localLock: LocalLockService = {
      acquire: () =>
        Effect.acquireRelease(
          Effect.sync(() => {
            locks += 1
          }),
          () =>
            Effect.sync(() => {
              locks -= 1
            })
        ).pipe(Effect.asVoid)
    }
    const layer = Layer.mergeAll(
      NodeContext.layer,
      Layer.succeed(ProcessRunner, runner),
      Layer.succeed(LocalLock, localLock)
    )
    const run = <A, E>(
      effect: Effect.Effect<
        A,
        E,
        FileSystem.FileSystem | LocalLock | ProcessRunner
      >
    ) => Effect.runPromise(effect.pipe(Effect.provide(layer)))

    await run(
      Effect.gen(function* () {
        const fiber = yield* Effect.fork(
          ensureImage(catalog, inventory, "fixture-vllm")
        )
        yield* Effect.promise(() => buildStartedPromise)
        yield* Fiber.interrupt(fiber)
      })
    )
    assert.equal(locks, 0)
    assert.equal(builds, 0)
    assert.equal(pushes, 0)

    const prepared = await run(ensureImage(catalog, inventory, "fixture-vllm"))
    assert.equal(prepared.registry.digest, digest)
    assert.equal(prepared.local.state, "ready")
    assert.equal(builds, 1)
    assert.equal(pushes, 1)
    assert.equal(pulls, 1)
    assert.equal(locks, 0)

    await run(ensureImage(catalog, inventory, "fixture-vllm"))
    assert.equal(builds, 1)
    assert.equal(pushes, 1)
    assert.equal(pulls, 1)

    localReady = false
    const restored = await run(
      ensureImage(catalog, inventory, "fixture-vllm")
    )
    assert.equal(restored.local.state, "ready")
    assert.equal(builds, 1)
    assert.equal(pushes, 1)
    assert.equal(pulls, 2)

    const workerInventory = { ...inventory, localNode: "spark-02" }
    localReady = false
    const workerRestored = await run(
      ensureImage(catalog, workerInventory, "fixture-vllm")
    )
    assert.equal(workerRestored.local.state, "ready")
    assert.equal(builds, 1)
    assert.equal(pushes, 1)
    assert.equal(pulls, 3)

    registryDigest = undefined
    localReady = false
    const unpublished = await run(
      Effect.either(ensureImage(catalog, workerInventory, "fixture-vllm"))
    )
    assert.ok(Either.isLeft(unpublished))
    assert.equal(unpublished.left.code, "image-not-published")
    assert.equal(builds, 1)
    assert.equal(pushes, 1)

    const build = requests.find(
      (request) =>
        request.command === "podman" && request.args[0] === "build"
    )
    assert.ok(build)
    assert.deepEqual(build.args.slice(0, 7), [
      "build",
      "--pull=missing",
      "--platform",
      "linux/arm64",
      "--file",
      "/nix/store/fixture-containerfile",
      "--build-arg"
    ])
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})

test("image status reports registry failures without claiming absence", async () => {
  const runner: ProcessRunnerService = {
    foreground: () =>
      Effect.fail(
        new CommandError({
          code: "unexpected-test-command",
          message: "Status must not run foreground commands"
        })
      ),
    probe: () => Effect.succeed(outcome(1, "", "connection refused")),
    run: () =>
      Effect.fail(
        new CommandError({
          code: "unexpected-test-command",
          message: "Status must not mutate the image store"
        })
      )
  }
  const status = await Effect.runPromise(
    imageStatus(catalog, baseInventory, "fixture-vllm").pipe(
      Effect.provide(Layer.succeed(ProcessRunner, runner))
    )
  )
  assert.equal(status.registry.state, "unavailable")
  assert.equal(status.local.state, "unknown")
})

test("image status rejects invalid digests and local inspection failures", async () => {
  const invalidDigest: ProcessRunnerService = {
    foreground: () => Effect.die("unexpected foreground command"),
    probe: (request) =>
      Effect.succeed(
        request.command === "skopeo"
          ? outcome(0, "not-a-digest\n")
          : outcome(0)
      ),
    run: () => Effect.die("status must not mutate images")
  }
  const invalid = await Effect.runPromise(
    imageStatus(catalog, baseInventory, "fixture-vllm").pipe(
      Effect.provide(Layer.succeed(ProcessRunner, invalidDigest))
    )
  )
  assert.equal(invalid.registry.state, "unavailable")
  assert.deepEqual(invalid.registry.issues, [
    "the registry returned an invalid image digest"
  ])

  const localFailure: ProcessRunnerService = {
    foreground: () => Effect.die("unexpected foreground command"),
    probe: (request) =>
      Effect.succeed(
        request.command === "skopeo"
          ? outcome(0, `${digest}\n`)
          : outcome(2, "", "storage failure")
      ),
    run: () => Effect.die("status must not mutate images")
  }
  const failed = await Effect.runPromise(
    Effect.either(
      imageStatus(catalog, baseInventory, "fixture-vllm").pipe(
        Effect.provide(Layer.succeed(ProcessRunner, localFailure))
      )
    )
  )
  assert.ok(Either.isLeft(failed))
  assert.equal(failed.left.code, "image-status-failed")
})

test("image ensure verifies publication and local retention", async () => {
  const temporary = mkdtempSync(path.join(tmpdir(), "inference-image-errors-"))
  const inventory: Inventory = {
    ...baseInventory,
    modelStore: {
      ...baseInventory.modelStore,
      localRoot: path.join(temporary, "models")
    }
  }
  const localLock: LocalLockService = {
    acquire: () => Effect.void
  }
  const run = <A, E>(
    effect: Effect.Effect<
      A,
      E,
      FileSystem.FileSystem | LocalLock | ProcessRunner
    >,
    runner: ProcessRunnerService
  ) =>
    Effect.runPromise(
      effect.pipe(
        Effect.provide(
          Layer.mergeAll(
            NodeContext.layer,
            Layer.succeed(LocalLock, localLock),
            Layer.succeed(ProcessRunner, runner)
          )
        )
      )
    )

  try {
    const unpublished: ProcessRunnerService = {
      foreground: () => Effect.die("unexpected foreground command"),
      probe: (request) =>
        Effect.succeed(
          request.command === "skopeo"
            ? outcome(1, "", "manifest unknown")
            : outcome(1)
        ),
      run: () => Effect.succeed({ stdout: "", stderr: "" })
    }
    const publication = await run(
      Effect.either(ensureImage(catalog, inventory, "fixture-vllm")),
      unpublished
    )
    assert.ok(Either.isLeft(publication))
    assert.equal(publication.left.code, "image-publication-failed")

    let pulls = 0
    const notRetained: ProcessRunnerService = {
      foreground: () => Effect.die("unexpected foreground command"),
      probe: (request) =>
        Effect.succeed(
          request.command === "skopeo"
            ? outcome(0, `${digest}\n`)
            : outcome(1)
        ),
      run: (request) =>
        Effect.sync(() => {
          if (request.command === "podman" && request.args[0] === "pull") {
            pulls += 1
          }
          return { stdout: "", stderr: "" }
        })
    }
    const retention = await run(
      Effect.either(ensureImage(catalog, inventory, "fixture-vllm")),
      notRetained
    )
    assert.ok(Either.isLeft(retention))
    assert.equal(retention.left.code, "image-ensure-failed")
    assert.equal(pulls, 1)
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})
