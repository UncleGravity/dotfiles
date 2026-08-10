import { Result, Schema } from "effect"

export const decodeStrictJson = <
  S extends Schema.ConstraintDecoder<unknown, never>
>(
  schema: S,
  raw: string
): Result.Result<S["Type"], Schema.SchemaError> =>
  Schema.decodeUnknownResult(Schema.fromJsonString(schema), {
    errors: "all",
    onExcessProperty: "error"
  })(raw)

export const formatParseError = (error: Schema.SchemaError): string =>
  String(error.issue)
