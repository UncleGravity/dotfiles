import { Schema } from "effect"

const CommandErrorDetails = Schema.Record(Schema.String, Schema.Unknown)

export class CommandError extends Schema.Error<CommandError>("CommandError")({
  code: Schema.String,
  message: Schema.String,
  details: Schema.optionalKey(CommandErrorDetails)
}) {}

export const CommandErrorContract = Schema.Struct({
  schemaVersion: Schema.Literal(1),
  code: CommandError.fields.code,
  message: CommandError.fields.message,
  details: CommandError.fields.details
})
export type CommandErrorJson = typeof CommandErrorContract.Type

export const commandErrorJson = (error: CommandError): CommandErrorJson =>
  CommandErrorContract.make({
    schemaVersion: 1,
    code: error.code,
    message: error.message,
    ...(error.details === undefined ? {} : { details: error.details })
  })
