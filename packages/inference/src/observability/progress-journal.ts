import { Effect, Layer, Schema } from "effect"
import {
  ProgressEvent,
  ProgressEvents,
  makeProgressEvents,
  type ProgressEvent as ProgressEventValue
} from "./progress.js"

export const progressJournalPrefix = "@infer-progress "

export const encodeProgressJournalMessage = (
  event: ProgressEventValue
): string => `${progressJournalPrefix}${JSON.stringify(event)}`

export const decodeProgressJournalMessage = (
  message: string
): ProgressEventValue | undefined => {
  if (!message.startsWith(progressJournalPrefix)) return undefined
  try {
    const value: unknown = JSON.parse(message.slice(progressJournalPrefix.length))
    return Schema.is(ProgressEvent)(value) ? value : undefined
  } catch {
    return undefined
  }
}

export const makeProgressJournalSink = (
  write: (message: string) => unknown = (message) => process.stdout.write(message)
) =>
  (event: ProgressEventValue): Effect.Effect<void> =>
    Effect.sync(() => {
      try {
        write(`${encodeProgressJournalMessage(event)}\n`)
      } catch {
        // Observability must not fail inference work.
      }
    })

export const ProgressJournalLive = Layer.succeed(
  ProgressEvents,
  makeProgressEvents(makeProgressJournalSink())
)
