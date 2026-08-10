import { Effect, Option } from "effect"
import { Argument, Command, Flag } from "effect/unstable/cli"
import { loadContract } from "../adapters/contract-files.js"
import {
  Inventory,
  type ModelEnsureResult,
  type ModelStatus
} from "../domain/contracts.js"
import { CommandError } from "../domain/errors.js"
import {
  artifactIdentity,
  normalizeSelection,
  parseModelReference
} from "../domain/model-artifact.js"
import {
  archiveModel,
  ensureModel,
  modelStatus,
  verifyModel
} from "../workflows/model-store.js"
import { handleCommand, printOutput } from "./output.js"

const modelArgument = Argument.string("model").pipe(
  Argument.withDescription("Pinned model in ORG/REPO@COMMIT form")
)

const inventoryOption = Flag.string("inventory").pipe(
  Flag.withDefault("/etc/infer/inventory.json"),
  Flag.withDescription("Path to the evaluated deployment inventory")
)

const includeOption = Flag.string("include").pipe(
  Flag.atLeast(0),
  Flag.withDescription("Relative Hugging Face include pattern")
)

const excludeOption = Flag.string("exclude").pipe(
  Flag.atLeast(0),
  Flag.withDescription("Relative Hugging Face exclude pattern")
)

const jsonOption = Flag.boolean("json").pipe(
  Flag.withDescription("Write one versioned JSON value")
)

const seedOption = Flag.string("seed").pipe(
  Flag.optional,
  Flag.withDescription(
    "Seed archive staging from an existing Hugging Face local directory"
  )
)

const sourceOption = Flag.string("source").pipe(
  Flag.optional,
  Flag.withDescription(
    "Pull from a declared node's read-only model store over fabric0"
  )
)

const common = {
  model: modelArgument,
  inventory: inventoryOption,
  include: includeOption,
  exclude: excludeOption,
  json: jsonOption
}

const resolve = (
  model: string,
  include: ReadonlyArray<string>,
  exclude: ReadonlyArray<string>
) =>
  Effect.gen(function* () {
    const reference = yield* Effect.fromResult(parseModelReference(model))
    const selection = yield* Effect.fromResult(
      normalizeSelection(include, exclude)
    )
    return artifactIdentity(reference.repo, reference.revision, selection)
  })

const renderStatus = (status: ModelStatus): string =>
  [
    `Model: ${status.artifact.repo}@${status.artifact.revision}`,
    `Selection: ${status.artifact.selectionHash}`,
    `Archive: ${status.archive.state} (${status.archive.path})`,
    `Local: ${status.local.state} (${status.local.path})`
  ].join("\n")

const renderEnsure = (result: ModelEnsureResult): string =>
  [
    `Model: ${result.artifact.repo}@${result.artifact.revision}`,
    `Selection: ${result.artifact.selectionHash}`,
    `Source: ${result.source.kind === "archive" ? "archive" : result.source.node}`,
    `Local: ${result.local.state} (${result.local.path})`
  ].join("\n")

const requireControlNode = (
  inventory: Inventory
): Effect.Effect<void, CommandError> =>
  inventory.localNode === inventory.controlNode
    ? Effect.void
    : Effect.fail(
        new CommandError({
          code: "control-node-required",
          message: `Model mutations must run on '${inventory.controlNode}'`,
          details: {
            controlNode: inventory.controlNode,
            localNode: inventory.localNode
          }
        })
      )

type CommonOptions = {
  readonly model: string
  readonly inventory: string
  readonly include: ReadonlyArray<string>
  readonly exclude: ReadonlyArray<string>
  readonly json: boolean
}

const makeHandler = <R>(
  operation: (
    inventory: Inventory,
    artifact: ReturnType<typeof artifactIdentity>
  ) => Effect.Effect<ModelStatus, CommandError, R>,
  controlNodeOnly = false
) =>
  ({ model, inventory, include, exclude, json }: CommonOptions) =>
    handleCommand(
      json,
      Effect.gen(function* () {
        const artifact = yield* resolve(model, include, exclude)
        const loadedInventory = yield* loadContract(
          inventory,
          "Inventory",
          Inventory
        )
        if (controlNodeOnly) yield* requireControlNode(loadedInventory.value)
        const value = yield* operation(loadedInventory.value, artifact)
        yield* printOutput(json, value, renderStatus(value))
      })
    )

const status = Command.make(
  "status",
  common,
  makeHandler((inventory, artifact) => modelStatus(inventory, artifact))
).pipe(Command.withDescription("Inspect archive and local model readiness"))

const verify = Command.make(
  "verify",
  common,
  makeHandler(verifyModel)
).pipe(Command.withDescription("Verify every archived and local model byte"))

const archive = Command.make(
  "archive",
  {...common, seed: seedOption},
  ({ seed, ...options }) =>
    makeHandler(
      (inventory, artifact) =>
        archiveModel(inventory, artifact, Option.getOrUndefined(seed)),
      true
    )(options)
).pipe(Command.withDescription("Download and publish a pinned model to the archive"))

const ensure = Command.make(
  "ensure",
  {...common, source: sourceOption},
  ({ source, model, inventory, include, exclude, json }) =>
    handleCommand(
      json,
      Effect.gen(function* () {
        const artifact = yield* resolve(model, include, exclude)
        const loadedInventory = yield* loadContract(
          inventory,
          "Inventory",
          Inventory
        )
        const sourceNode = Option.getOrUndefined(source)
        if (sourceNode === undefined) {
          yield* requireControlNode(loadedInventory.value)
        }
        const value = yield* ensureModel(
          loadedInventory.value,
          artifact,
          sourceNode
        )
        yield* printOutput(json, value, renderEnsure(value))
      })
    )
).pipe(Command.withDescription("Materialize an archived model on local storage"))

export const modelsCommand = Command.make("models").pipe(
  Command.withDescription("Manage immutable inference model artifacts"),
  Command.withSubcommands([archive, ensure, status, verify])
)
