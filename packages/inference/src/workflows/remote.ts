import { FileSystem } from "effect"
import { Console, Effect } from "effect"
import { loadContract } from "../adapters/contract-files.js"
import { ProcessRunner } from "../adapters/process-runner.js"
import {
  InstanceCatalog,
  Inventory,
  type InstanceDeclaration,
  type RemoteUnitStatus
} from "../domain/contracts.js"
import { CommandError } from "../domain/errors.js"

type RemoteAction = "prepare" | "lease" | "stop" | "status"

interface RemoteRequest {
  readonly action: RemoteAction
  readonly instance: string
}

const instancePattern = /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/

export const parseRemoteRequest = (
  raw: string
): Effect.Effect<RemoteRequest, CommandError> => {
  const parts = raw.trim().split(/\s+/)
  const action = parts[0]
  const instance = parts[1]
  return parts.length === 2 &&
    (action === "prepare" ||
      action === "lease" ||
      action === "stop" ||
      action === "status") &&
    instance !== undefined &&
    instancePattern.test(instance)
    ? Effect.succeed({ action, instance })
    : Effect.fail(
        new CommandError({
          code: "invalid-remote-command",
          message: "Remote inference command is not allowed"
        })
      )
}

const requireLocalClusterInstance = (
  instances: InstanceCatalog,
  inventory: Inventory,
  name: string
): Effect.Effect<InstanceDeclaration, CommandError> => {
  const instance = instances.instances.find((candidate) => candidate.name === name)
  return instance === undefined ||
    instance.nodes.length < 2 ||
    !instance.nodes.includes(inventory.localNode)
    ? Effect.fail(
        new CommandError({
          code: "remote-instance-not-allowed",
          message: `Clustered instance '${name}' is not allocated to '${inventory.localNode}'`,
          details: { instance: name, localNode: inventory.localNode }
        })
      )
    : Effect.succeed(instance)
}

const parseProperties = (output: string): ReadonlyMap<string, string> =>
  new Map(
    output
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => line.includes("="))
      .map((line) => {
        const separator = line.indexOf("=")
        return [line.slice(0, separator), line.slice(separator + 1)] as const
      })
  )

export const readUnitStatus = (
  instance: string,
  node: string,
  unit: string
): Effect.Effect<RemoteUnitStatus, CommandError, ProcessRunner> =>
  Effect.gen(function* () {
    const runner = yield* ProcessRunner
    const result = yield* runner.run({
      command: "systemctl",
      args: [
        "show",
        unit,
        "--property=LoadState",
        "--property=ActiveState",
        "--property=SubState",
        "--property=Result",
        "--no-pager"
      ]
    })
    const properties = parseProperties(result.stdout)
    return {
      schemaVersion: 1,
      instance,
      node,
      loadState: properties.get("LoadState") || "unknown",
      activeState: properties.get("ActiveState") || "unknown",
      subState: properties.get("SubState") || "unknown",
      result: properties.get("Result") || "unknown"
    }
  })

export const runRemoteCommand = (
  raw: string
): Effect.Effect<
  void,
  CommandError,
  FileSystem.FileSystem | ProcessRunner
> =>
  Effect.gen(function* () {
    const request = yield* parseRemoteRequest(raw)
    const [inventory, instances] = yield* Effect.all([
      loadContract("/etc/infer/inventory.json", "Inventory", Inventory),
      loadContract(
        "/etc/infer/instances.json",
        "InstanceCatalog",
        InstanceCatalog
      )
    ])
    yield* requireLocalClusterInstance(
      instances.value,
      inventory.value,
      request.instance
    )

    if (request.action === "prepare") {
      const runner = yield* ProcessRunner
      yield* runner.run({
        command: "systemctl",
        args: ["start", `infer-prepare-${request.instance}.service`]
      })
      return
    }

    const unit = `infer-node-${request.instance}.service`
    const runner = yield* ProcessRunner
    if (request.action === "lease") {
      yield* Effect.scoped(
        Effect.acquireRelease(
          runner.run({
            command: "systemctl",
            args: ["start", "--no-block", unit]
          }),
          () =>
            runner
              .run({ command: "systemctl", args: ["stop", unit] })
              .pipe(Effect.orElseSucceed(() => ({ stdout: "", stderr: "" })))
        ).pipe(Effect.andThen(Effect.never))
      )
      return
    }
    if (request.action === "stop") {
      yield* runner.run({ command: "systemctl", args: ["stop", unit] })
      return
    }

    const status = yield* readUnitStatus(
      request.instance,
      inventory.value.localNode,
      unit
    )
    yield* Console.log(JSON.stringify(status))
  })
