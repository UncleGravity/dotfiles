import { FileSystem } from "@effect/platform"
import { Effect, Either } from "effect"
import type { Schema as SchemaType } from "effect/Schema"
import { CommandError } from "../domain/errors.js"
import { decodeStrictJson, formatParseError } from "../domain/json-contract.js"

export interface LoadedContract<A> {
  readonly value: A
  readonly raw: string
}

export const loadContract = <A, I>(
  path: string,
  name: string,
  schema: SchemaType<A, I, never>
): Effect.Effect<LoadedContract<A>, CommandError, FileSystem.FileSystem> =>
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
    const value = yield* decodeStrictJson(schema, raw).pipe(
      Either.mapLeft(
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
    return { value, raw }
  })
