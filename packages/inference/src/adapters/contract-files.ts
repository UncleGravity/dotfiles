import { FileSystem } from "@effect/platform"
import { Effect, ParseResult, Schema } from "effect"
import type { Schema as SchemaType } from "effect/Schema"
import { CommandError } from "../domain/errors.js"

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
    const value = yield* Schema.decodeUnknown(Schema.parseJson(schema), {
      errors: "all",
      onExcessProperty: "error"
    })(raw).pipe(
      Effect.mapError(
        (error) =>
          new CommandError({
            code: "invalid-contract",
            message: `${name} at '${path}' does not match schema version 1`,
            details: {
              name,
              path,
              parseError: ParseResult.TreeFormatter.formatErrorSync(error)
            }
          })
      )
    )
    return { value, raw }
  })
