import { Effect, FileSystem, Result, Schema } from "effect"
import { CommandError } from "../domain/errors.js"
import { decodeStrictJson, formatParseError } from "../domain/json-contract.js"

export interface LoadedContract<A> {
  readonly value: A
  readonly raw: string
}

export const loadContract = <
  S extends Schema.ConstraintDecoder<unknown, never>
>(
  path: string,
  name: string,
  schema: S
): Effect.Effect<
  LoadedContract<S["Type"]>,
  CommandError,
  FileSystem.FileSystem
> =>
  Effect.gen(function* () {
    const fileSystem = yield* FileSystem.FileSystem
    const raw = yield* fileSystem.readFileString(path, "utf8").pipe(
      Effect.mapError(
        () =>
          new CommandError({
            code: "contract-read-failed",
            message: `Unable to read ${name} from '${path}'`,
            details: { name, path }
          })
      )
    )
    const value = yield* Effect.fromResult(
      decodeStrictJson(schema, raw).pipe(
        Result.mapError(
          (error) =>
            new CommandError({
              code: "invalid-contract",
              message: `${name} at '${path}' does not match schema version 1`,
              details: {
                name,
                path,
                parseError: formatParseError(error)
              }
            })
        )
      )
    )
    return { value, raw }
  })
