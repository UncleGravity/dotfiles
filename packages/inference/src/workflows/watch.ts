import { FileSystem } from "effect"
import { Effect, Stream } from "effect"
import { loadContract } from "../adapters/contract-files.js"
import { JournalReader } from "../adapters/journal-reader.js"
import { InstanceCatalog, Inventory } from "../domain/contracts.js"
import { CommandError } from "../domain/errors.js"
import { findInstance } from "../domain/planner.js"
import {
  emptyPipelineSnapshot,
  reducePipelineUpdate,
  type PipelineSnapshot,
  type PipelineUpdate
} from "../observability/pipeline.js"

export interface WatchInstanceRequest {
  readonly instance: string
  readonly inventoryPath: string
  readonly instancesPath: string
  readonly follow: boolean
}

const journalReplayLines = 500

export const watchInstance = (
  request: WatchInstanceRequest
): Stream.Stream<
  PipelineSnapshot,
  CommandError,
  FileSystem.FileSystem | JournalReader
> =>
  Stream.unwrap(
    Effect.gen(function* () {
      const [loadedInventory, loadedInstances] = yield* Effect.all([
        loadContract(request.inventoryPath, "Inventory", Inventory),
        loadContract(request.instancesPath, "InstanceCatalog", InstanceCatalog)
      ])
      const declaration = yield* Effect.fromResult(
        findInstance(loadedInstances.value, request.instance)
      )
      const inventory = loadedInventory.value
      if (
        declaration.nodes.length > 1 &&
        inventory.localNode !== inventory.controlNode
      ) {
        return yield* Effect.fail(
          new CommandError({
            code: "watch-control-node-required",
            message: `Watch clustered instance '${request.instance}' on '${inventory.controlNode}'`,
            details: {
              instance: request.instance,
              localNode: inventory.localNode,
              controlNode: inventory.controlNode
            }
          })
        )
      }
      if (
        declaration.nodes.length === 1 &&
        declaration.nodes[0] !== inventory.localNode
      ) {
        return yield* Effect.fail(
          new CommandError({
            code: "watch-local-node-required",
            message: `Watch instance '${request.instance}' on '${declaration.nodes[0]}'`,
            details: {
              instance: request.instance,
              localNode: inventory.localNode,
              instanceNode: declaration.nodes[0]
            }
          })
        )
      }

      const reader = yield* JournalReader
      const unit = `infer-${request.instance}.service`
      const eventUpdates = reader
        .events({
          unit,
          follow: request.follow,
          lines: journalReplayLines
        })
        .pipe(
          Stream.map(
            (observed): PipelineUpdate => ({ type: "event", observed })
          )
        )
      const statusUpdates = request.follow
        ? Stream.tick("2 seconds").pipe(
            Stream.mapEffect(() => reader.status(unit)),
            Stream.map(
              (status): PipelineUpdate => ({ type: "unit", status })
            )
          )
        : Stream.fromEffect(reader.status(unit)).pipe(
            Stream.map(
              (status): PipelineUpdate => ({ type: "unit", status })
            )
          )
      const streams: ReadonlyArray<
        Stream.Stream<PipelineUpdate, CommandError>
      > = request.follow
        ? [
            eventUpdates,
            statusUpdates,
            Stream.tick("1 second").pipe(
              Stream.map((): PipelineUpdate => ({ type: "tick" }))
            )
          ]
        : [eventUpdates, statusUpdates]
      const initial = emptyPipelineSnapshot({
        instance: declaration.name,
        recipe: declaration.recipe,
        nodes: declaration.nodes,
        controlNode: inventory.controlNode
      })
      return Stream.mergeAll(streams, { concurrency: streams.length }).pipe(
        Stream.scan(initial, reducePipelineUpdate)
      )
    })
  )
