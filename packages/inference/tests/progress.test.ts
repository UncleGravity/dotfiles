import assert from "node:assert/strict"
import test from "node:test"
import { Effect, Metric, Schema, Stream } from "effect"
import {
  makeProgressHub,
  ProgressEvent
} from "../src/observability/progress.js"

test("progress events are versioned, observable, and metered", async () => {
  const program = Effect.gen(function* () {
    const hub = yield* makeProgressHub()
    yield* hub.service.emit({
      kind: "lifecycle",
      state: "started",
      scope: "cluster",
      operation: "prepare-node",
      message: "Preparing 'node-b'",
      instance: "fixture",
      node: "node-b"
    })
    const events = yield* hub.events.pipe(Stream.take(1), Stream.runCollect)
    const metrics = yield* Metric.snapshot
    return { event: events[0], metrics }
  }).pipe(Effect.provideService(Metric.MetricRegistry, new Map()))

  const { event, metrics } = await Effect.runPromise(program)
  assert.equal(Schema.is(ProgressEvent)(event), true)
  assert.equal(event?.schemaVersion, 1)
  assert.equal(event?.operation, "prepare-node")
  assert.equal(event?.instance, "fixture")
  assert.equal(
    metrics.some((metric) => metric.id === "inference_progress_events_total"),
    true
  )
})
