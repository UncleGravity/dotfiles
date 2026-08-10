import assert from "node:assert/strict"
import test from "node:test"
import { Effect, Result } from "effect"
import {
  decodeJournalRecord,
  decodeUnitStatus,
  journalExitSucceeded
} from "../src/adapters/journal-reader.js"
import { renderPipeline } from "../src/cli/watch-view.js"
import {
  emptyPipelineSnapshot,
  pipelineStatus,
  reducePipelineUpdate,
  type ObservedProgressEvent,
  type PipelineSnapshot
} from "../src/observability/pipeline.js"
import {
  decodeProgressJournalMessage,
  encodeProgressJournalMessage,
  makeProgressJournalSink
} from "../src/observability/progress-journal.js"
import { ProgressEvent } from "../src/observability/progress.js"

const lifecycle = (
  operation: string,
  state: "started" | "completed" | "failed" | "warning",
  timestamp: string,
  options: {
    readonly scope?: "cluster" | "instance" | "model"
    readonly node?: string
    readonly model?: string
    readonly message?: string
    readonly attributes?: Readonly<Record<string, unknown>>
  } = {}
) =>
  ProgressEvent.make({
    schemaVersion: 1,
    timestamp,
    kind: "lifecycle",
    scope: options.scope ?? "instance",
    operation,
    state,
    message: options.message ?? `${operation} ${state}`,
    instance: "fixture",
    ...(options.node === undefined ? {} : { node: options.node }),
    ...(options.model === undefined ? {} : { model: options.model }),
    ...(options.attributes === undefined
      ? {}
      : { attributes: options.attributes })
  })

const observed = (
  event: ReturnType<typeof lifecycle>,
  invocationId = "invocation-a"
): ObservedProgressEvent => ({ event, invocationId })

const initial = (): PipelineSnapshot =>
  emptyPipelineSnapshot({
    instance: "fixture",
    recipe: "fixture-vllm",
    nodes: ["spark-01", "spark-02"],
    controlNode: "spark-01"
  })

test("progress journal messages round-trip through the event schema", () => {
  const event = lifecycle(
    "ensure-model",
    "started",
    "2026-08-09T20:00:00.000Z"
  )
  const encoded = encodeProgressJournalMessage(event)
  assert.deepEqual(decodeProgressJournalMessage(encoded), event)
  assert.equal(decodeProgressJournalMessage("ordinary output"), undefined)
  assert.equal(decodeProgressJournalMessage("@infer-progress {}"), undefined)
})

test("journal output failures cannot fail inference progress", async () => {
  const event = lifecycle(
    "ensure-model",
    "started",
    "2026-08-09T20:00:00.000Z"
  )
  const sink = makeProgressJournalSink(() => {
    throw new Error("closed output")
  })
  await Effect.runPromise(sink(event))
})

test("journal records preserve invocation and cursor metadata", () => {
  const event = lifecycle(
    "ensure-image",
    "completed",
    "2026-08-09T20:01:00.000Z"
  )
  const decoded = decodeJournalRecord(
    `\u001e${JSON.stringify({
      __CURSOR: "cursor-a",
      _HOSTNAME: "spark-01",
      _SYSTEMD_INVOCATION_ID: "invocation-a",
      MESSAGE: encodeProgressJournalMessage(event)
    })}`
  )
  assert.equal(Result.isSuccess(decoded), true)
  if (Result.isFailure(decoded)) return
  assert.equal(decoded.success?.invocationId, "invocation-a")
  assert.equal(decoded.success?.cursor, "cursor-a")
  assert.equal(decoded.success?.hostname, "spark-01")
  assert.deepEqual(decoded.success?.event, event)
})

test("systemd status decoding requires the complete unit state", () => {
  const decoded = decodeUnitStatus(
    "infer-fixture.service",
    [
      "LoadState=loaded",
      "ActiveState=activating",
      "SubState=start",
      "Result=success",
      "InvocationID=invocation-a",
      "StatusText=Preparing image"
    ].join("\n"),
    "2026-08-09T20:02:00.000Z"
  )
  assert.equal(Result.isSuccess(decoded), true)
  if (Result.isFailure(decoded)) return
  assert.equal(decoded.success.activeState, "activating")
  assert.equal(decoded.success.statusText, "Preparing image")
})

test("an empty finite journal replay is not a command failure", () => {
  assert.equal(journalExitSucceeded(0, false, ""), true)
  assert.equal(journalExitSucceeded(1, false, ""), true)
  assert.equal(journalExitSucceeded(1, false, "permission denied"), false)
  assert.equal(journalExitSucceeded(0, true, ""), false)
})

test("the reducer infers sequential phase completion and keeps numeric progress", () => {
  let snapshot = initial()
  snapshot = reducePipelineUpdate(snapshot, {
    type: "event",
    observed: observed(
      lifecycle(
        "copy-local",
        "started",
        "2026-08-09T20:00:00.000Z",
        { scope: "model", model: "example/model@revision" }
      )
    )
  })
  snapshot = reducePipelineUpdate(snapshot, {
    type: "event",
    observed: observed(
      lifecycle(
        "verify-local",
        "started",
        "2026-08-09T20:01:00.000Z",
        { scope: "model", model: "example/model@revision" }
      )
    )
  })
  const copy = snapshot.steps.find((step) => step.operation === "copy-local")
  assert.equal(copy?.state, "completed")
  assert.equal(copy?.completionInferred, true)

  const progress = ProgressEvent.make({
    schemaVersion: 1,
    timestamp: "2026-08-09T20:02:00.000Z",
    kind: "progress",
    scope: "cluster",
    operation: "wait-for-nodes",
    message: "1 of 2 node units are active",
    instance: "fixture",
    current: 1,
    total: 2,
    unit: "nodes"
  })
  snapshot = reducePipelineUpdate(snapshot, {
    type: "event",
    observed: { event: progress, invocationId: "invocation-a" }
  })
  assert.deepEqual(
    snapshot.steps.find((step) => step.operation === "wait-for-nodes")?.progress,
    { current: 1, total: 2, unit: "nodes" }
  )
})

test("node lanes remain independent and a new invocation resets the run", () => {
  let snapshot = initial()
  for (const node of ["spark-02", "spark-03"]) {
    snapshot = reducePipelineUpdate(snapshot, {
      type: "event",
      observed: observed(
        lifecycle(
          "prepare-node",
          "started",
          "2026-08-09T20:00:00.000Z",
          { scope: "cluster", node }
        )
      )
    })
  }
  assert.equal(
    snapshot.steps.filter((step) => step.state === "running").length,
    2
  )

  snapshot = reducePipelineUpdate(snapshot, {
    type: "event",
    observed: observed(
      lifecycle("load-contracts", "started", "2026-08-09T21:00:00.000Z"),
      "invocation-b"
    )
  })
  assert.equal(snapshot.invocationId, "invocation-b")
  assert.deepEqual(snapshot.steps.map((step) => step.operation), ["load-contracts"])
})

test("a stale unit poll cannot replace a newer invocation", () => {
  let snapshot = reducePipelineUpdate(initial(), {
    type: "event",
    observed: observed(
      lifecycle("load-contracts", "started", "2026-08-09T21:00:01.000Z"),
      "invocation-b"
    )
  })
  snapshot = reducePipelineUpdate(snapshot, {
    type: "unit",
    status: {
      unit: "infer-fixture.service",
      observedAt: "2026-08-09T21:00:00.000Z",
      loadState: "loaded",
      activeState: "activating",
      subState: "start",
      result: "success",
      invocationId: "invocation-a"
    }
  })
  assert.equal(snapshot.invocationId, "invocation-b")
  assert.deepEqual(snapshot.steps.map((step) => step.operation), ["load-contracts"])
})

test("a pipeline failure aborts the running phase in the same lane", () => {
  let snapshot = reducePipelineUpdate(initial(), {
    type: "event",
    observed: observed(
      lifecycle("wait-for-health", "started", "2026-08-09T20:00:00.000Z")
    )
  })
  snapshot = reducePipelineUpdate(snapshot, {
    type: "event",
    observed: observed(
      lifecycle("pipeline", "failed", "2026-08-09T20:01:00.000Z")
    )
  })
  assert.equal(
    snapshot.steps.find((step) => step.operation === "wait-for-health")?.state,
    "failed"
  )
})

test("unit state drives ready and failed aggregate status", () => {
  const ready = reducePipelineUpdate(initial(), {
    type: "unit",
    status: {
      unit: "infer-fixture.service",
      observedAt: "2026-08-09T20:00:00.000Z",
      loadState: "loaded",
      activeState: "active",
      subState: "running",
      result: "success",
      invocationId: "invocation-a"
    }
  })
  assert.equal(pipelineStatus(ready), "ready")
  const failed = reducePipelineUpdate(ready, {
    type: "unit",
    status: {
      unit: "infer-fixture.service",
      observedAt: "2026-08-09T20:01:00.000Z",
      loadState: "loaded",
      activeState: "failed",
      subState: "failed",
      result: "exit-code"
    }
  })
  assert.equal(pipelineStatus(failed), "failed")
})

test("the plain renderer distinguishes node launch from systemd readiness", () => {
  let snapshot = initial()
  const events = [
    lifecycle(
      "start-node",
      "completed",
      "2026-08-09T20:00:01.000Z",
      {
        scope: "cluster",
        node: "spark-01",
        message: "Launch accepted for 'spark-01'"
      }
    ),
    lifecycle(
      "node-readiness",
      "started",
      "2026-08-09T20:00:02.000Z",
      {
        scope: "cluster",
        node: "spark-01",
        message: "Waiting for head API health",
        attributes: {
          role: "head",
          loadState: "loaded",
          activeState: "activating",
          subState: "start",
          result: "success"
        }
      }
    ),
    lifecycle(
      "prepare-node",
      "completed",
      "2026-08-09T20:00:03.000Z",
      {
        scope: "cluster",
        node: "spark-02",
        message: "Prepared 'spark-02'"
      }
    ),
    lifecycle(
      "start-node",
      "completed",
      "2026-08-09T20:00:04.000Z",
      {
        scope: "cluster",
        node: "spark-02",
        message: "Launch accepted for 'spark-02'"
      }
    ),
    lifecycle(
      "node-readiness",
      "started",
      "2026-08-09T20:00:05.000Z",
      {
        scope: "cluster",
        node: "spark-02",
        message: "Waiting for worker readiness",
        attributes: {
          role: "worker",
          loadState: "loaded",
          activeState: "activating",
          subState: "start",
          result: "success"
        }
      }
    ),
    lifecycle(
      "node-readiness",
      "completed",
      "2026-08-09T20:00:20.000Z",
      {
        scope: "cluster",
        node: "spark-02",
        message: "Worker is ready",
        attributes: {
          role: "worker",
          loadState: "loaded",
          activeState: "active",
          subState: "running",
          result: "success"
        }
      }
    )
  ]
  for (const event of events) {
    snapshot = reducePipelineUpdate(snapshot, {
      type: "event",
      observed: observed(event)
    })
  }
  const output = renderPipeline(snapshot, {
    width: 120,
    height: 28,
    now: Date.parse("2026-08-09T20:01:00.000Z"),
    color: false,
    footer: true
  })
  assert.match(output, /INFER fixture/)
  assert.match(output, /CONTROLLER/)
  assert.match(output, /spark-01/)
  assert.match(output, /spark-02/)
  assert.match(output, /LAUNCH\s+UNIT STATE\s+DETAIL/)
  assert.match(output, /\[>\] activating\/start\s+Waiting for head API health \(00:58\)/)
  assert.match(output, /\[ok\] active\/running\s+Ready in 00:15/)
  assert.match(output, /Ctrl-C to exit/)
  assert.equal(output.includes("\u001b"), false)

  const compact = renderPipeline(snapshot, {
    width: 80,
    height: 24,
    now: Date.parse("2026-08-09T20:01:00.000Z"),
    color: false,
    footer: true
  })
  assert.match(compact, /LAUNCH\s+UNIT STATE/)
  assert.equal(
    compact.split("\n").every((line) => line.length <= 80),
    true
  )

  const narrow = renderPipeline(snapshot, {
    width: 40,
    height: 24,
    now: Date.parse("2026-08-09T20:01:00.000Z"),
    color: false,
    footer: true
  })
  assert.match(narrow, /NODE\s+RUN\s+UNIT STATE/)
  assert.match(narrow, /\[>\] activating\/start/)
  assert.equal(
    narrow.split("\n").every((line) => line.length <= 40),
    true
  )

  for (const event of [
    lifecycle(
      "stop-node",
      "started",
      "2026-08-09T20:01:01.000Z",
      {
        scope: "cluster",
        node: "spark-02",
        message: "Stopping 'spark-02'"
      }
    ),
    lifecycle(
      "stop-node",
      "completed",
      "2026-08-09T20:01:02.000Z",
      {
        scope: "cluster",
        node: "spark-02",
        message: "Stopped 'spark-02'"
      }
    )
  ]) {
    snapshot = reducePipelineUpdate(snapshot, {
      type: "event",
      observed: observed(event)
    })
  }
  const stopped = renderPipeline(snapshot, {
    width: 120,
    height: 28,
    now: Date.parse("2026-08-09T20:02:00.000Z"),
    color: false,
    footer: true
  })
  assert.match(stopped, /spark-02.*\[--\] stopped.*Stopped by controller/)
})

test("the live layout respects a 24-row terminal", () => {
  let snapshot = initial()
  for (let index = 0; index < 14; index += 1) {
    snapshot = reducePipelineUpdate(snapshot, {
      type: "event",
      observed: observed(
        lifecycle(
          `phase-${index}`,
          "started",
          `2026-08-09T20:${index.toString().padStart(2, "0")}:00.000Z`
        )
      )
    })
  }
  const output = renderPipeline(snapshot, {
    width: 80,
    height: 24,
    now: Date.parse("2026-08-09T21:00:00.000Z"),
    color: false,
    footer: true
  })
  assert.equal(output.split("\n").length <= 24, true)
})
