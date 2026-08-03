import { Data, Schema } from "effect"

export class CommandError extends Data.TaggedError("CommandError")<{
  readonly code: string
  readonly message: string
  readonly details?: Readonly<Record<string, unknown>>
}> {}

export interface CommandErrorJson {
  readonly schemaVersion: 1
  readonly code: string
  readonly message: string
  readonly details?: Readonly<Record<string, unknown>>
}

export const CommandErrorContract = Schema.Struct({
  schemaVersion: Schema.Literal(1),
  code: Schema.String,
  message: Schema.String,
  details: Schema.optional(
    Schema.Record({ key: Schema.String, value: Schema.Unknown })
  )
})

export const commandErrorJson = (error: CommandError): CommandErrorJson => ({
  schemaVersion: 1,
  code: error.code,
  message: error.message,
  ...(error.details === undefined ? {} : { details: error.details })
})
