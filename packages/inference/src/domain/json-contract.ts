import { Either, ParseResult, Schema } from "effect"
import type { Schema as SchemaType } from "effect/Schema"

export const decodeStrictJson = <A, I>(
  schema: SchemaType<A, I, never>,
  raw: string
): Either.Either<A, ParseResult.ParseError> =>
  Schema.decodeUnknownEither(Schema.parseJson(schema), {
    errors: "all",
    onExcessProperty: "error"
  })(raw)

export const formatParseError = (error: ParseResult.ParseError): string =>
  ParseResult.TreeFormatter.formatErrorSync(error)
