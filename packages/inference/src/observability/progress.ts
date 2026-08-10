import {
  Clock,
  Context,
  Effect,
  Metric,
  PubSub,
  Schema,
  Stream
} from "effect"

const ProgressEventBase = {
  schemaVersion: Schema.Literal(1),
  timestamp: Schema.String,
  scope: Schema.Literals(["cluster", "instance", "model", "image", "remote"]),
  operation: Schema.NonEmptyString,
  message: Schema.NonEmptyString,
  instance: Schema.optionalKey(Schema.NonEmptyString),
  node: Schema.optionalKey(Schema.NonEmptyString),
  model: Schema.optionalKey(Schema.NonEmptyString),
  attributes: Schema.optionalKey(Schema.Record(Schema.String, Schema.Unknown))
} as const

export const ProgressEvent = Schema.Union([
  Schema.Struct({
    ...ProgressEventBase,
    kind: Schema.Literal("lifecycle"),
    state: Schema.Literals(["started", "completed", "failed", "warning"])
  }),
  Schema.Struct({
    ...ProgressEventBase,
    kind: Schema.Literal("progress"),
    current: Schema.Number.check(Schema.isFinite(), Schema.isGreaterThanOrEqualTo(0)),
    total: Schema.Number.check(Schema.isFinite(), Schema.isGreaterThanOrEqualTo(0)),
    unit: Schema.NonEmptyString
  })
])

export type ProgressEvent = typeof ProgressEvent.Type
export type ProgressEventInput =
  | Omit<Extract<ProgressEvent, { readonly kind: "lifecycle" }>, "schemaVersion" | "timestamp">
  | Omit<Extract<ProgressEvent, { readonly kind: "progress" }>, "schemaVersion" | "timestamp">

export interface ProgressEventsService {
  readonly emit: (input: ProgressEventInput) => Effect.Effect<void>
}

export interface ProgressHub {
  readonly service: ProgressEventsService
  readonly events: Stream.Stream<ProgressEvent>
}

const eventCount = Metric.counter("inference_progress_events_total", {
  description: "Inference lifecycle and progress events",
  incremental: true
})

const displayMessage = (event: ProgressEvent): string => {
  switch (event.scope) {
    case "cluster":
      return `[infer:${event.instance ?? "unknown"}:cluster] ${event.message}`
    case "instance":
      return `[infer:${event.instance ?? "unknown"}] ${event.message}`
    case "model":
      return `[models] ${event.message}`
    case "image":
      return `[images] ${event.message}`
    case "remote":
      return `[remote:${event.node ?? "unknown"}] ${event.message}`
  }
}

export const makeProgressEvents = (
  sink: (event: ProgressEvent) => Effect.Effect<void> = () => Effect.void
): ProgressEventsService => ({
  emit: (input) =>
    Effect.gen(function* () {
      const now = yield* Clock.currentTimeMillis
      const event = ProgressEvent.make({
        ...input,
        schemaVersion: 1,
        timestamp: new Date(now).toISOString()
      })
      const metric = Metric.withAttributes(eventCount, {
        scope: event.scope,
        operation: event.operation,
        state: event.kind === "lifecycle" ? event.state : "progress"
      })
      yield* Metric.update(metric, 1)
      yield* Effect.logInfo(displayMessage(event)).pipe(
        Effect.annotateLogs({
          "inference.event.kind": event.kind,
          "inference.event.operation": event.operation,
          "inference.event.scope": event.scope,
          ...(event.instance === undefined
            ? {}
            : { "inference.instance": event.instance }),
          ...(event.node === undefined ? {} : { "inference.node": event.node }),
          ...(event.model === undefined ? {} : { "inference.model": event.model })
        })
      )
      yield* sink(event)
    })
})

export const ProgressEvents = Context.Reference<ProgressEventsService>(
  "inference/ProgressEvents",
  { defaultValue: makeProgressEvents }
)

export const emitProgress = (input: ProgressEventInput): Effect.Effect<void> =>
  ProgressEvents.use((events) => events.emit(input))

export const makeProgressHub = (): Effect.Effect<ProgressHub> =>
  Effect.gen(function* () {
    const pubsub = yield* PubSub.unbounded<ProgressEvent>({ replay: 32 })
    return {
      service: makeProgressEvents((event) =>
        PubSub.publish(pubsub, event).pipe(Effect.asVoid)
      ),
      events: Stream.fromPubSub(pubsub)
    }
  })
