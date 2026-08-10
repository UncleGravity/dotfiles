import { Effect } from "effect"
import { commandErrorJson, type CommandError } from "../domain/errors.js"

const writeStdout = (value: string): Effect.Effect<void> =>
  Effect.sync(() => {
    process.stdout.write(`${value}\n`)
  })

const writeStderr = (value: string): Effect.Effect<void> =>
  Effect.sync(() => {
    process.stderr.write(`${value}\n`)
  })

export const printOutput = (
  json: boolean,
  value: unknown,
  human: string
): Effect.Effect<void> =>
  writeStdout(json ? JSON.stringify(value, null, 2) : human)

export const handleCommand = <R>(
  json: boolean,
  effect: Effect.Effect<void, CommandError, R>
): Effect.Effect<void, never, R> =>
  effect.pipe(
    Effect.catch((error) =>
      writeStderr(
        json
          ? JSON.stringify(commandErrorJson(error))
          : `${error.code}: ${error.message}`
      ).pipe(
        Effect.andThen(
          Effect.sync(() => {
            process.exitCode = 1
          })
        )
      )
    )
  )
