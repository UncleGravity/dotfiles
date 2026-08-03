import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import {
  Duration,
  Effect,
  Either,
  Fiber,
  Layer,
  Schema,
  TestClock,
  TestContext
} from "effect"
import {
  HealthProbe,
  type HealthProbeService
} from "../src/adapters/health-probe.js"
import {
  InstanceCatalog,
  Inventory,
  RunPlan
} from "../src/domain/contracts.js"
import {
  ProcessRunner,
  ProcessRunnerLive,
  type ProcessRequest,
  type ProcessRunnerService
} from "../src/adapters/process-runner.js"
import { CommandError } from "../src/domain/errors.js"
import {
  containerArguments,
  monitorHealth,
  runPreparedInstance,
  type PreparedInstance,
  waitUntilHealthy
} from "../src/workflows/instance.js"
import { clusterStartGroups } from "../src/workflows/cluster.js"

const contracts = "tests/fixtures/contracts/v1"
const plan = Schema.decodeUnknownSync(RunPlan)(
  JSON.parse(readFileSync(`${contracts}/run-plan.json`, "utf8"))
)
const instances = Schema.decodeUnknownSync(InstanceCatalog)(
  JSON.parse(readFileSync(`${contracts}/instances.json`, "utf8"))
)
const inventory = Schema.decodeUnknownSync(Inventory)(
  JSON.parse(readFileSync(`${contracts}/inventory.json`, "utf8"))
)

const runWithHealth = <A, E>(
  effect: Effect.Effect<A, E, HealthProbe>,
  health: HealthProbeService
): Promise<A> =>
  Effect.runPromise(
    effect.pipe(
      Effect.provide(Layer.succeed(HealthProbe, health)),
      Effect.provide(TestContext.TestContext)
    )
  )

test("an instance plan becomes one shell-free Podman argv", () => {
  const image = {
    reference: `registry.example/infer/fixture@sha256:${"d".repeat(64)}`,
    digest: `sha256:${"d".repeat(64)}`
  }
  const args = containerArguments(
    instances.instances[0]!,
    plan,
    plan.nodePlans[0]!,
    image,
    "invocation-id"
  )
  assert.deepEqual(args.slice(0, 11), [
    "run",
    "--rm",
    "--pull=never",
    "--log-driver=none",
    "--cgroups=disabled",
    "--name",
    "infer-fixture",
    "--network",
    "host",
    "--label",
    "io.angel.infer.instance=fixture"
  ])
  assert.ok(args.includes("io.angel.infer.invocation-id=invocation-id"))
  assert.ok(args.includes("nvidia.com/gpu=all"))
  assert.ok(args.includes("--volume"))
  assert.ok(args.includes(image.reference))
  assert.deepEqual(args.slice(-3), [
    "/models/target",
    "--served-model-name",
    "fixture"
  ])
})

test("container mounts preserve explicit writable access", () => {
  const writablePlan = Schema.decodeUnknownSync(RunPlan)({
    ...plan,
    nodePlans: plan.nodePlans.map((nodePlan, index) =>
      index === 0
        ? {
            ...nodePlan,
            container: {
              ...nodePlan.container,
              mounts: [
                ...nodePlan.container.mounts,
                {
                  sourcePath: "/var/cache/fixture",
                  targetPath: "/root/.cache",
                  readOnly: false
                }
              ]
            }
          }
        : nodePlan
    )
  })
  const image = {
    reference: `registry.example/infer/fixture@sha256:${"d".repeat(64)}`,
    digest: `sha256:${"d".repeat(64)}`
  }
  const args = containerArguments(
    instances.instances[0]!,
    writablePlan,
    writablePlan.nodePlans[0]!,
    image
  )

  assert.ok(args.includes("/var/cache/fixture:/root/.cache:rw"))
  assert.ok(args.some((argument) => argument.endsWith(":ro")))
})

test("container arguments select the requested worker plan", () => {
  const image = {
    reference: `registry.example/infer/fixture@sha256:${"d".repeat(64)}`,
    digest: `sha256:${"d".repeat(64)}`
  }
  const worker = plan.nodePlans.find((nodePlan) => nodePlan.role === "worker")
  assert.ok(worker)

  const args = containerArguments(
    instances.instances[0]!,
    plan,
    worker,
    image
  )
  assert.ok(args.includes("io.angel.infer.role=worker"))
  assert.ok(args.includes("INFER_ROLE=worker"))
  assert.ok(args.includes(`INFER_NODE=${worker.node}`))
})

test("cluster start groups preserve the declared role order", () => {
  assert.deepEqual(clusterStartGroups(plan), [
    plan.nodes.filter((node) => node !== plan.head),
    [plan.head]
  ])
  assert.deepEqual(clusterStartGroups({ ...plan, startOrder: "head-first" }), [
    [plan.head],
    plan.nodes.filter((node) => node !== plan.head)
  ])
  assert.deepEqual(clusterStartGroups({ ...plan, startOrder: "parallel" }), [
    plan.nodes
  ])
})

test("startup health requires consecutive successes", async () => {
  const responses = [true, false, true, true]
  let probes = 0
  const health: HealthProbeService = {
    reachable: () =>
      Effect.sync(() => responses[probes++] ?? false)
  }

  await runWithHealth(
    Effect.gen(function* () {
      const container = yield* Effect.fork(Effect.never)
      const startup = yield* Effect.fork(waitUntilHealthy(plan, container))
      yield* TestClock.adjust(Duration.seconds(6))
      yield* Fiber.join(startup)
    }),
    health
  )
  assert.equal(probes, 4)
})

test("startup timeout follows the Effect test clock", async () => {
  const timedPlan = {
    ...plan,
    endpoint: { ...plan.endpoint, startupTimeoutSeconds: 5 }
  }
  const health: HealthProbeService = {
    reachable: () => Effect.succeed(false)
  }

  const result = await runWithHealth(
    Effect.gen(function* () {
      const container = yield* Effect.fork(Effect.never)
      const startup = yield* Effect.fork(
        waitUntilHealthy(timedPlan, container)
      )
      yield* TestClock.adjust(Duration.seconds(5))
      return yield* Effect.either(Fiber.join(startup))
    }),
    health
  )
  assert.ok(Either.isLeft(result))
  assert.equal(result.left.code, "startup-timeout")
})

test("health monitoring fails after three consecutive misses", async () => {
  let probes = 0
  const health: HealthProbeService = {
    reachable: () =>
      Effect.sync(() => {
        probes += 1
        return false
      })
  }

  const result = await runWithHealth(
    Effect.gen(function* () {
      const container = yield* Effect.fork(Effect.never)
      const monitor = yield* Effect.fork(monitorHealth(plan, container))
      yield* TestClock.adjust(Duration.seconds(30))
      return yield* Effect.either(Fiber.join(monitor))
    }),
    health
  )
  assert.ok(Either.isLeft(result))
  assert.equal(result.left.code, "endpoint-unhealthy")
  assert.equal(probes, 3)
})

test("health monitoring resets its failure count after recovery", async () => {
  const responses = [false, false, true, false, false, false]
  let probes = 0
  const health: HealthProbeService = {
    reachable: () => Effect.succeed(responses[probes++] ?? false)
  }

  const result = await runWithHealth(
    Effect.gen(function* () {
      const container = yield* Effect.fork(Effect.never)
      const monitor = yield* Effect.fork(monitorHealth(plan, container))
      yield* TestClock.adjust(Duration.seconds(60))
      return yield* Effect.either(Fiber.join(monitor))
    }),
    health
  )
  assert.ok(Either.isLeft(result))
  assert.equal(result.left.code, "endpoint-unhealthy")
  assert.equal(probes, 6)
})

test("container exits become one stable lifecycle error", async () => {
  const health: HealthProbeService = {
    reachable: () => Effect.succeed(false)
  }
  const sourceError = new CommandError({
    code: "external-command-failed",
    message: "Podman exited"
  })

  const startup = await runWithHealth(
    Effect.gen(function* () {
      const container = yield* Effect.fork(Effect.fail(sourceError))
      yield* Fiber.await(container)
      return yield* Effect.either(waitUntilHealthy(plan, container))
    }),
    health
  )
  assert.ok(Either.isLeft(startup))
  assert.equal(startup.left.code, "container-exited")

  const monitoring = await runWithHealth(
    Effect.gen(function* () {
      const container = yield* Effect.fork(Effect.fail(sourceError))
      yield* Fiber.await(container)
      const monitor = yield* Effect.fork(monitorHealth(plan, container))
      yield* TestClock.adjust("10 seconds")
      return yield* Effect.either(Fiber.join(monitor))
    }),
    health
  )
  assert.ok(Either.isLeft(monitoring))
  assert.equal(monitoring.left.code, "container-exited")
})

test("prepared instance notifies readiness and releases its container", async () => {
  let firstProbe!: () => void
  let notified!: () => void
  const firstProbePromise = new Promise<void>((resolve) => {
    firstProbe = resolve
  })
  const notifiedPromise = new Promise<void>((resolve) => {
    notified = resolve
  })
  let probes = 0
  let released = false
  let foregroundRequest: ProcessRequest | undefined
  const runner: ProcessRunnerService = {
    foreground: (request) =>
      Effect.scoped(
        Effect.acquireRelease(
          Effect.sync(() => {
            foregroundRequest = request
          }),
          () =>
            Effect.sync(() => {
              released = true
            })
        ).pipe(Effect.zipRight(Effect.never))
      ),
    probe: () => Effect.die("unexpected probe command"),
    run: (request) =>
      Effect.sync(() => {
        assert.equal(request.command, "systemd-notify")
        notified()
        return { stdout: "", stderr: "" }
      })
  }
  const health: HealthProbeService = {
    reachable: () =>
      Effect.sync(() => {
        probes += 1
        if (probes === 1) firstProbe()
        return true
      })
  }
  const prepared: PreparedInstance = {
    declaration: instances.instances[0]!,
    inventory: { ...inventory, localNode: "spark-02" },
    plan,
    image: {
      reference: `registry.example/infer/fixture@sha256:${"d".repeat(64)}`,
      digest: `sha256:${"d".repeat(64)}`
    }
  }

  await Effect.runPromise(
    Effect.gen(function* () {
      const fiber = yield* Effect.fork(
        runPreparedInstance("fixture", prepared, "test-invocation")
      )
      yield* Effect.promise(() => firstProbePromise)
      yield* TestClock.adjust("2 seconds")
      yield* Effect.promise(() => notifiedPromise)
      yield* Fiber.interrupt(fiber)
    }).pipe(
      Effect.provide(Layer.succeed(HealthProbe, health)),
      Effect.provide(Layer.succeed(ProcessRunner, runner)),
      Effect.provide(TestContext.TestContext)
    )
  )

  assert.equal(probes, 2)
  assert.equal(foregroundRequest?.command, "podman")
  assert.ok(
    foregroundRequest?.args.includes(
      "io.angel.infer.invocation-id=test-invocation"
    )
  )
  assert.equal(released, true)
})

test("worker notification failure releases its container", async () => {
  let started!: () => void
  const startedPromise = new Promise<void>((resolve) => {
    started = resolve
  })
  let released = false
  const runner: ProcessRunnerService = {
    foreground: () =>
      Effect.scoped(
        Effect.acquireRelease(
          Effect.sync(started),
          () =>
            Effect.sync(() => {
              released = true
            })
        ).pipe(Effect.zipRight(Effect.never))
      ),
    probe: () => Effect.die("unexpected probe command"),
    run: () =>
      Effect.fail(
        new CommandError({
          code: "notify-failed",
          message: "systemd notification failed"
        })
      )
  }
  const prepared: PreparedInstance = {
    declaration: instances.instances[0]!,
    inventory,
    plan,
    image: {
      reference: `registry.example/infer/fixture@sha256:${"d".repeat(64)}`,
      digest: `sha256:${"d".repeat(64)}`
    }
  }

  const result = await Effect.runPromise(
    Effect.gen(function* () {
      const fiber = yield* Effect.fork(
        runPreparedInstance("fixture", prepared)
      )
      yield* Effect.promise(() => startedPromise)
      yield* TestClock.adjust("2 seconds")
      return yield* Effect.either(Fiber.join(fiber))
    }).pipe(
      Effect.provide(
        Layer.succeed(HealthProbe, {
          reachable: () => Effect.die("worker must not probe health")
        })
      ),
      Effect.provide(Layer.succeed(ProcessRunner, runner)),
      Effect.provide(TestContext.TestContext)
    )
  )

  assert.ok(Either.isLeft(result))
  assert.equal(result.left.code, "notify-failed")
  assert.equal(released, true)
})

test("process input tolerates a child closing stdin early", async () => {
  const outcome = await Effect.runPromise(
    Effect.gen(function* () {
      const runner = yield* ProcessRunner
      return yield* runner.probe({
        command: "true",
        args: [],
        input: "x".repeat(1024 * 1024)
      })
    }).pipe(Effect.provide(ProcessRunnerLive))
  )
  assert.equal(outcome.exitCode, 0)
})
