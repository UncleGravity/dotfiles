import { createHash } from "node:crypto"
import { Result } from "effect"
import type {
  ArtifactIdentity,
  ModelSelection
} from "./contracts.js"
import { CommandError } from "./errors.js"

export interface ModelReference {
  readonly repo: string
  readonly revision: string
}

const hash = (value: string): string =>
  createHash("sha256").update(value, "utf8").digest("hex")

const compareAscii = (left: string, right: string): number =>
  left < right ? -1 : left > right ? 1 : 0

const normalizePatterns = (
  values: ReadonlyArray<string>,
  kind: "include" | "exclude"
): Result.Result<ReadonlyArray<string>, CommandError> => {
  const invalid = values.find(
    (value) =>
      value.length === 0 ||
      value.startsWith("/") ||
      value.split("/").includes("..")
  )
  if (invalid !== undefined) {
    return Result.fail(
      new CommandError({
        code: "invalid-model-selection",
        message: `The --${kind} pattern '${invalid}' is not a safe relative pattern`,
        details: { kind, pattern: invalid }
      })
    )
  }
  return Result.succeed([...new Set(values)].sort(compareAscii))
}

export const normalizeSelection = (
  include: ReadonlyArray<string>,
  exclude: ReadonlyArray<string>
): Result.Result<ModelSelection, CommandError> =>
  Result.gen(function* () {
    const normalizedInclude = yield* normalizePatterns(include, "include")
    const normalizedExclude = yield* normalizePatterns(exclude, "exclude")
    return {
      include: normalizedInclude,
      exclude: normalizedExclude
    }
  })

export const selectionHash = (selection: ModelSelection): string =>
  hash(
    JSON.stringify({
      exclude: selection.exclude,
      include: selection.include
    })
  )

export const artifactIdentity = (
  repo: string,
  revision: string,
  selection: ModelSelection
): ArtifactIdentity => {
  const digest = selectionHash(selection)
  return {
    source: "hf",
    repo,
    revision,
    selection,
    selectionHash: digest,
    relativePath: `hf/${repo}/${revision}/${digest}`
  }
}

export const parseModelReference = (
  value: string
): Result.Result<ModelReference, CommandError> => {
  const match = /^([^/\s]+\/[^/@\s]+)@([0-9a-f]{40})$/.exec(value)
  return match === null
    ? Result.fail(
        new CommandError({
          code: "invalid-model-reference",
          message: `Model '${value}' must use ORG/REPO@COMMIT form with a lowercase 40-character commit`,
          details: { model: value }
        })
      )
    : Result.succeed({ repo: match[1]!, revision: match[2]! })
}
