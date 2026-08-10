import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import {
  Effect,
  Result,
  Fiber,
  Layer,
  Schema
} from "effect"
import { TestClock } from "effect/testing"
import {
  ProcessRunner,
  type ProcessRequest,
  type ProcessRunnerService
} from "../src/adapters/process-runner.js"
import {
  Inventory,
  RemoteUnitStatus,
  RunPlan
} from "../src/domain/contracts.js"
import { CommandError } from "../src/domain/errors.js"
import {
  ProgressEvents,
  type ProgressEventInput,
  type ProgressEventsService
} from "../src/observability/progress.js"
import {
  decodeRemoteStatus,
  runPreparedCluster
} from "../src/workflows/cluster.js"

const contracts = "tests/fixtures/contracts/v1"
const inventory = Schema.decodeUnknownSync(Inventory)(
  JSON.parse(readFileSync(`${contracts}/inventory.json`, "utf8"))
)
const plan = Schema.decodeUnknownSync(RunPlan)(
  JSON.parse(readFileSync(`${contracts}/run-plan.json`, "utf8"))
)

const status = (node: string, activeState = "active"): RemoteUnitStatus => ({
  schemaVersion: 1,
  instance: "fixture",
  node,
  loadState: "loaded",
  activeState,
  subState: activeState === "active" ? "running" : "dead",
  result: activeState === "failed" ? "oom-kill" : "success"
})

const systemdStatus = (activeState = "active") => ({
  stdout: [
    "LoadState=loaded",
    `ActiveState=${activeState}`,
    `SubState=${activeState === "active" ? "running" : "dead"}`,
    "Result=success"
  ].join("\n"),
  stderr: ""
})

const remoteAction = (request: ProcessRequest): string | undefined =>
  request.command === "ssh" ? request.args.at(-1) : undefined

const captureProgress = (
  events: Array<ProgressEventInput>
): ProgressEventsService => ({
  emit: (event) =>
    Effect.sync(() => {
      events.push(event)
    })
})

test("remote status decoding is strict and identifies the source node", () => {
  const valid = decodeRemoteStatus(
    JSON.stringify(status("spark-02")),
    "spark-02",
    "fixture"
  )
  assert.ok(Result.isSuccess(valid))
  assert.equal(valid.success.node, "spark-02")

  for (const raw of [
    "not-json",
    JSON.stringify({ ...status("spark-02"), unexpected: true })
  ]) {
    const invalid = decodeRemoteStatus(raw, "spark-02", "fixture")
    assert.ok(Result.isFailure(invalid))
    assert.equal(invalid.failure.code, "cluster-status-invalid")
    assert.equal(invalid.failure.details?.node, "spark-02")
  }

  for (const mismatched of [
    { ...status("spark-03") },
    { ...status("spark-02"), instance: "other" }
  ]) {
    const invalid = decodeRemoteStatus(
      JSON.stringify(mismatched),
      "spark-02",
      "fixture"
    )
    assert.ok(Result.isFailure(invalid))
    assert.equal(invalid.failure.code, "cluster-status-identity-mismatch")
  }
})

test("prepared cluster reaches readiness and cleans up every node", async () => {
  const events: Array<string> = []
  const progressEvents: Array<ProgressEventInput> = []
  let ready!: () => void
  let leaseStarted!: () => void
  const readyPromise = new Promise<void>((resolve) => {
    ready = resolve
  })
  const leasePromise = new Promise<void>((resolve) => {
    leaseStarted = resolve
  })

  const runner: ProcessRunnerService = {
    foreground: (request) =>
      Effect.scoped(
        Effect.acquireRelease(
          Effect.sync(() => {
            events.push(`lease:${remoteAction(request)}`)
            leaseStarted()
          }),
          () =>
            Effect.sync(() => {
              events.push("lease:released")
            })
        ).pipe(Effect.andThen(Effect.never))
      ),
    probe: () =>
      Effect.fail(
        new CommandError({
          code: "unexpected-test-probe",
          message: "Cluster coordination must not probe commands"
        })
      ),
    run: (request) =>
      Effect.sync(() => {
        const action = remoteAction(request)
        if (action !== undefined) {
          events.push(`ssh:${action}`)
          if (action === "status fixture") {
            return {
              stdout: JSON.stringify(status("spark-02")),
              stderr: ""
            }
          }
          return { stdout: "", stderr: "" }
        }
        if (request.command === "systemctl") {
          events.push(`systemctl:${request.args.slice(0, 2).join(":")}`)
          return request.args[0] === "show"
            ? systemdStatus()
            : { stdout: "", stderr: "" }
        }
        if (request.command === "systemd-notify") {
          events.push("ready")
          ready()
          return { stdout: "", stderr: "" }
        }
        throw new Error(`Unexpected command '${request.command}'`)
      }).pipe(
        Effect.mapError(
          () =>
            new CommandError({
              code: "unexpected-test-command",
              message: `Unexpected cluster command '${request.command}'`
            })
        )
      )
  }

  const program = Effect.gen(function* () {
    const fiber = yield* Effect.forkChild(
      runPreparedCluster("fixture", inventory, plan)
    )
    yield* Effect.promise(() => leasePromise)
    yield* Effect.sleep("150 millis")
    yield* Effect.promise(() => readyPromise)
    yield* Fiber.interrupt(fiber)
  }).pipe(
    Effect.provide(Layer.succeed(ProcessRunner, runner)),
    Effect.provideService(ProgressEvents, captureProgress(progressEvents))
  )

  await Effect.runPromise(program)
  assert.ok(events.indexOf("ssh:prepare fixture") < events.indexOf("lease:lease fixture"))
  assert.ok(events.indexOf("systemctl:start:--no-block") < events.indexOf("lease:lease fixture"))
  assert.ok(events.includes("ready"))
  assert.ok(events.includes("lease:released"))
  assert.deepEqual(
    events.filter((event) => event.includes("stop")),
    ["systemctl:stop:infer-node-fixture.service", "ssh:stop fixture"]
  )
  assert.deepEqual(
    progressEvents
      .filter((event) => event.operation === "node-readiness")
      .map((event) => ({
        node: event.node,
        state: event.kind === "lifecycle" ? event.state : event.kind,
        activeState: event.attributes?.activeState,
        subState: event.attributes?.subState
      })),
    [
      {
        node: "spark-02",
        state: "completed",
        activeState: "active",
        subState: "running"
      },
      {
        node: "spark-01",
        state: "completed",
        activeState: "active",
        subState: "running"
      }
    ]
  )
  assert.deepEqual(
    progressEvents
      .filter(
        (event) =>
          event.kind === "lifecycle" &&
          event.operation === "stop-node" &&
          event.state === "completed"
      )
      .map((event) => event.node),
    ["spark-01", "spark-02"]
  )
})

test("remote node preparation runs with bounded concurrency", async () => {
  const clusterInventory: Inventory = {
    ...inventory,
    nodes: [
      ...inventory.nodes,
      {
        name: "spark-03",
        platform: "linux/arm64",
        managementAddress: "192.168.1.33",
        fabric: {
          fabric0: "10.100.0.3",
          fabric1: "10.100.1.3"
        }
      },
      {
        name: "spark-04",
        platform: "linux/arm64",
        managementAddress: "192.168.1.34",
        fabric: {
          fabric0: "10.100.0.4",
          fabric1: "10.100.1.4"
        }
      }
    ]
  }
  const clusterPlan: RunPlan = {
    ...plan,
    startOrder: "head-first",
    nodes: ["spark-01", "spark-02", "spark-03", "spark-04"],
    head: "spark-01",
    endpoint: {
      ...plan.endpoint,
      node: "spark-01",
      healthUrl: "http://192.168.1.31:8000/health"
    }
  }
  let activePreparations = 0
  let peakPreparations = 0
  let ready!: () => void
  const readyPromise = new Promise<void>((resolve) => {
    ready = resolve
  })
  const remoteNode = (request: ProcessRequest) => {
    const target = request.args.find((arg) => arg.startsWith("infer-remote@"))
    return clusterInventory.nodes.find(
      (node) => target === `infer-remote@${node.fabric.fabric0}`
    )
  }
  const runner: ProcessRunnerService = {
    foreground: () => Effect.never,
    probe: () => Effect.die("unexpected probe"),
    run: (request) => {
      const action = remoteAction(request)
      if (action === "prepare fixture") {
        return Effect.acquireUseRelease(
          Effect.sync(() => {
            activePreparations += 1
            peakPreparations = Math.max(
              peakPreparations,
              activePreparations
            )
          }),
          () =>
            Effect.sleep("50 millis").pipe(
              Effect.as({ stdout: "", stderr: "" })
            ),
          () =>
            Effect.sync(() => {
              activePreparations -= 1
            })
        )
      }
      if (action === "status fixture") {
        const node = remoteNode(request)
        assert.ok(node)
        return Effect.succeed({
          stdout: JSON.stringify(status(node.name)),
          stderr: ""
        })
      }
      if (action !== undefined) {
        return Effect.succeed({ stdout: "", stderr: "" })
      }
      if (request.command === "systemctl") {
        return Effect.succeed(
          request.args[0] === "show"
            ? systemdStatus()
            : { stdout: "", stderr: "" }
        )
      }
      if (request.command === "systemd-notify") {
        ready()
        return Effect.succeed({ stdout: "", stderr: "" })
      }
      return Effect.die(`Unexpected command '${request.command}'`)
    }
  }

  await Effect.runPromise(
    Effect.gen(function* () {
      const fiber = yield* Effect.forkChild(
        runPreparedCluster("fixture", clusterInventory, clusterPlan)
      )
      yield* Effect.promise(() => readyPromise)
      yield* Fiber.interrupt(fiber)
    }).pipe(Effect.provide(Layer.succeed(ProcessRunner, runner)))
  )

  assert.equal(peakPreparations, 3)
  assert.equal(activePreparations, 0)
})

test("lost cluster lease fails startup and still stops every node", async () => {
  const stopped: Array<string> = []
  let leaseStarted!: () => void
  const leasePromise = new Promise<void>((resolve) => {
    leaseStarted = resolve
  })
  const runner: ProcessRunnerService = {
    foreground: () =>
      Effect.sync(leaseStarted).pipe(
        Effect.andThen(
          Effect.fail(
            new CommandError({
              code: "ssh-lease-ended",
              message: "SSH lease ended"
            })
          )
        )
      ),
    probe: () => Effect.die("unexpected probe"),
    run: (request) => {
      const action = remoteAction(request)
      if (action === "stop fixture") stopped.push("spark-02")
      if (request.command === "systemctl" && request.args[0] === "stop") {
        stopped.push("spark-01")
      }
      return Effect.succeed({ stdout: "", stderr: "" })
    }
  }

  const fiber = Effect.runFork(
    runPreparedCluster("fixture", inventory, plan).pipe(
      Effect.provide(Layer.succeed(ProcessRunner, runner))
    )
  )
  await leasePromise
  const result = await Effect.runPromise(Effect.result(Fiber.join(fiber)))
  assert.ok(Result.isFailure(result))
  assert.equal(result.failure.code, "cluster-lease-lost")
  assert.deepEqual(stopped, ["spark-01", "spark-02"])
})

test("cluster startup failure identifies the failed node and result", async () => {
  const progressEvents: Array<ProgressEventInput> = []
  const runner: ProcessRunnerService = {
    foreground: () => Effect.never,
    probe: () => Effect.die("unexpected probe"),
    run: (request) => {
      const action = remoteAction(request)
      if (action === "status fixture") {
        return Effect.succeed({
          stdout: JSON.stringify(status("spark-02", "failed")),
          stderr: ""
        })
      }
      if (request.command === "systemctl" && request.args[0] === "show") {
        return Effect.succeed(systemdStatus())
      }
      return Effect.succeed({ stdout: "", stderr: "" })
    }
  }

  const result = await Effect.runPromise(
    Effect.result(
      runPreparedCluster("fixture", inventory, plan).pipe(
        Effect.provide(Layer.succeed(ProcessRunner, runner)),
        Effect.provideService(ProgressEvents, captureProgress(progressEvents))
      )
    )
  )

  assert.ok(Result.isFailure(result))
  assert.equal(result.failure.code, "cluster-node-failed")
  assert.equal(
    result.failure.message,
    "Clustered inference startup failed: spark-02: oom-kill (loaded, failed/dead)"
  )
  const failedReadiness = progressEvents.findIndex(
    (event) =>
      event.kind === "lifecycle" &&
      event.operation === "node-readiness" &&
      event.node === "spark-02" &&
      event.state === "failed"
  )
  const failedWait = progressEvents.findIndex(
    (event) =>
      event.kind === "lifecycle" &&
      event.operation === "wait-for-nodes" &&
      event.state === "failed"
  )
  assert.notEqual(failedReadiness, -1)
  assert.equal(progressEvents[failedReadiness]?.attributes?.role, "head")
  assert.equal(progressEvents[failedReadiness]?.attributes?.result, "oom-kill")
  assert.equal(failedReadiness < failedWait, true)
})

test("cluster startup timeout reports the latest statuses and cleans up", async () => {
  let leaseStarted!: () => void
  let statusChecked!: () => void
  const leasePromise = new Promise<void>((resolve) => {
    leaseStarted = resolve
  })
  const statusPromise = new Promise<void>((resolve) => {
    statusChecked = resolve
  })
  const stopped: Array<string> = []
  const progressEvents: Array<ProgressEventInput> = []
  const runner: ProcessRunnerService = {
    foreground: () =>
      Effect.scoped(
        Effect.acquireRelease(Effect.sync(leaseStarted), () => Effect.void).pipe(
          Effect.andThen(Effect.never)
        )
      ),
    probe: () => Effect.die("unexpected probe"),
    run: (request) =>
      Effect.sync(() => {
        const action = remoteAction(request)
        if (action === "status fixture") {
          statusChecked()
          return {
            stdout: JSON.stringify(status("spark-02", "inactive")),
            stderr: ""
          }
        }
        if (action === "stop fixture") stopped.push("spark-02")
        if (request.command === "systemctl") {
          if (request.args[0] === "stop") stopped.push("spark-01")
          if (request.args[0] === "show") return systemdStatus("inactive")
        }
        return { stdout: "", stderr: "" }
      })
  }
  const timedPlan: RunPlan = {
    ...plan,
    endpoint: { ...plan.endpoint, startupTimeoutSeconds: 5 }
  }

  const result = await Effect.runPromise(
    Effect.gen(function* () {
      const fiber = yield* Effect.forkChild(
        runPreparedCluster("fixture", inventory, timedPlan)
      )
      yield* Effect.promise(() => leasePromise)
      yield* TestClock.adjust("100 millis")
      yield* Effect.promise(() => statusPromise)
      yield* TestClock.adjust("5 seconds")
      return yield* Effect.result(Fiber.join(fiber))
    }).pipe(
      Effect.provide(Layer.succeed(ProcessRunner, runner)),
      Effect.provideService(ProgressEvents, captureProgress(progressEvents)),
      Effect.provide(TestClock.layer())
    )
  )

  assert.ok(Result.isFailure(result))
  assert.equal(result.failure.code, "cluster-startup-timeout")
  assert.deepEqual(stopped, ["spark-01", "spark-02"])
  const statuses = result.failure.details?.statuses
  assert.ok(Array.isArray(statuses))
  assert.equal(statuses.length, 2)
  assert.deepEqual(
    progressEvents
      .filter((event) => event.operation === "node-readiness")
      .map((event) => ({
        node: event.node,
        state: event.kind === "lifecycle" ? event.state : event.kind,
        activeState: event.attributes?.activeState,
        subState: event.attributes?.subState,
        result: event.attributes?.result
      })),
    [
      {
        node: "spark-02",
        state: "started",
        activeState: "inactive",
        subState: "dead",
        result: "success"
      },
      {
        node: "spark-01",
        state: "started",
        activeState: "inactive",
        subState: "dead",
        result: "success"
      }
    ]
  )
})
