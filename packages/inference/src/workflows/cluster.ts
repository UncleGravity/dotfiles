import { FileSystem } from "@effect/platform"
import {
  Console,
  Duration,
  Effect,
  Either,
  Fiber,
  Option,
  Scope
} from "effect"
import { LocalLock } from "../adapters/local-lock.js"
import { ProcessRunner } from "../adapters/process-runner.js"
import {
  RemoteUnitStatus,
  type Inventory,
  type RunPlan
} from "../domain/contracts.js"
import { CommandError } from "../domain/errors.js"
import { decodeStrictJson, formatParseError } from "../domain/json-contract.js"
import { prepareInstance } from "./instance.js"
import { readUnitStatus } from "./remote.js"

type NodeAction = "prepare" | "lease" | "stop" | "status"

interface NodeLease {
  readonly node: string
  readonly fiber: Fiber.Fiber<void, CommandError>
}

const sshIdentity = "/etc/ssh/ssh_host_ed25519_key"
const sshKnownHosts = "/etc/ssh/ssh_known_hosts"

const phase = (instance: string, message: string): Effect.Effect<void> =>
  Console.error(`[infer:${instance}:cluster] ${message}`)

const findNode = (inventory: Inventory, name: string) =>
  inventory.nodes.find((candidate) => candidate.name === name)

const remoteArguments = (
  inventory: Inventory,
  nodeName: string,
  action: NodeAction,
  instance: string
): Effect.Effect<ReadonlyArray<string>, CommandError> => {
  const node = findNode(inventory, nodeName)
  const address = node?.fabric.fabric0
  return address === undefined
    ? Effect.fail(
        new CommandError({
          code: "cluster-node-unreachable",
          message: `Node '${nodeName}' has no fabric0 address`,
          details: { node: nodeName }
        })
      )
    : Effect.succeed([
        "-T",
        "-o",
        "BatchMode=yes",
        "-o",
        "IdentitiesOnly=yes",
        "-o",
        "StrictHostKeyChecking=yes",
        "-o",
        `UserKnownHostsFile=${sshKnownHosts}`,
        "-o",
        "ConnectTimeout=5",
        "-o",
        "ServerAliveInterval=10",
        "-o",
        "ServerAliveCountMax=3",
        "-i",
        sshIdentity,
        `infer-remote@${address}`,
        `${action} ${instance}`
      ])
}

const remoteAction = (
  inventory: Inventory,
  node: string,
  action: "prepare" | "stop",
  instance: string
): Effect.Effect<void, CommandError, ProcessRunner> =>
  Effect.gen(function* () {
    const runner = yield* ProcessRunner
    const args = yield* remoteArguments(inventory, node, action, instance)
    yield* runner.run({ command: "ssh", args })
  })

export const decodeRemoteStatus = (
  raw: string,
  node: string
): Either.Either<RemoteUnitStatus, CommandError> =>
  decodeStrictJson(RemoteUnitStatus, raw).pipe(
    Either.mapLeft(
      (error) =>
        new CommandError({
          code: "cluster-status-invalid",
          message: `Node '${node}' returned an invalid status contract`,
          details: {
            node,
            issues: formatParseError(error)
          }
        })
    )
  )

const statusNode = (
  inventory: Inventory,
  instance: string,
  node: string
): Effect.Effect<RemoteUnitStatus, CommandError, ProcessRunner> =>
  node === inventory.localNode
    ? readUnitStatus(
        instance,
        node,
        `infer-node-${instance}.service`
      )
    : Effect.gen(function* () {
        const runner = yield* ProcessRunner
        const args = yield* remoteArguments(
          inventory,
          node,
          "status",
          instance
        )
        const result = yield* runner.run({ command: "ssh", args })
        return yield* decodeRemoteStatus(result.stdout.trim(), node)
      })

const checkLeases = (
  leases: ReadonlyArray<NodeLease>
): Effect.Effect<void, CommandError> =>
  Effect.forEach(
    leases,
    ({ node, fiber }) =>
      Fiber.poll(fiber).pipe(
        Effect.flatMap(
          Option.match({
            onNone: () => Effect.void,
            onSome: () =>
              Fiber.join(fiber).pipe(
                Effect.either,
                Effect.flatMap((result) =>
                  Effect.fail(
                    new CommandError({
                      code: "cluster-lease-lost",
                      message: `The controller lease to '${node}' ended`,
                      details: {
                        node,
                        result: Either.isLeft(result)
                          ? result.left.message
                          : "remote command exited"
                      }
                    })
                  )
                )
              )
          })
        )
      ),
    { discard: true }
  )

const launchNode = (
  inventory: Inventory,
  instance: string,
  node: string
): Effect.Effect<
  Option.Option<NodeLease>,
  CommandError,
  ProcessRunner | Scope.Scope
> =>
  Effect.gen(function* () {
    if (node === inventory.localNode) {
      const runner = yield* ProcessRunner
      yield* runner.run({
        command: "systemctl",
        args: ["start", "--no-block", `infer-node-${instance}.service`]
      })
      return Option.none()
    }

    const runner = yield* ProcessRunner
    const args = yield* remoteArguments(inventory, node, "lease", instance)
    const fiber = yield* Effect.forkScoped(
      runner.foreground({ command: "ssh", args })
    )
    const lease = { node, fiber }
    yield* Effect.sleep("100 millis")
    yield* checkLeases([lease])
    return Option.some(lease)
  })

const stopNode = (
  inventory: Inventory,
  instance: string,
  node: string
): Effect.Effect<void, CommandError, ProcessRunner> =>
  node === inventory.localNode
    ? Effect.gen(function* () {
        const runner = yield* ProcessRunner
        yield* runner.run({
          command: "systemctl",
          args: ["stop", `infer-node-${instance}.service`]
        })
      })
    : remoteAction(inventory, node, "stop", instance)

export const clusterStartGroups = (
  plan: RunPlan
): ReadonlyArray<ReadonlyArray<string>> => {
  const workers = plan.nodes.filter((node) => node !== plan.head)
  return plan.startOrder === "workers-first"
    ? [workers, [plan.head]]
    : plan.startOrder === "head-first"
      ? [[plan.head], workers]
      : [plan.nodes]
}

const failedStatus = (status: RemoteUnitStatus): boolean =>
  status.loadState !== "loaded" || status.activeState === "failed"

const formatStatuses = (
  statuses: ReadonlyArray<RemoteUnitStatus>
): string =>
  statuses
    .map(
      (status) =>
        `${status.node}: ${status.result} (${status.loadState}, ${status.activeState}/${status.subState})`
    )
    .join(", ")

const waitUntilReady = (
  inventory: Inventory,
  plan: RunPlan,
  instance: string,
  leases: ReadonlyArray<NodeLease>
): Effect.Effect<void, CommandError, ProcessRunner> =>
  Effect.suspend(() => {
    let latest: ReadonlyArray<RemoteUnitStatus> = []
    return Effect.gen(function* () {
      while (true) {
        yield* checkLeases(leases)
        latest = yield* Effect.forEach(
          plan.nodes,
          (node) => statusNode(inventory, instance, node),
          { concurrency: "unbounded" }
        )
        const failed = latest.filter(failedStatus)
        if (failed.length > 0) {
          return yield* Effect.fail(
            new CommandError({
              code: "cluster-node-failed",
              message: `Clustered inference startup failed: ${formatStatuses(failed)}`,
              details: { nodes: failed }
            })
          )
        }
        if (latest.every((status) => status.activeState === "active")) return
        yield* Effect.sleep("2 seconds")
      }
    }).pipe(
      Effect.timeoutFail({
        duration: Duration.seconds(plan.endpoint.startupTimeoutSeconds),
        onTimeout: () =>
          new CommandError({
            code: "cluster-startup-timeout",
            message: "The clustered inference instance did not become ready",
            details: { statuses: latest }
          })
      })
    )
  })

const monitorCluster = (
  inventory: Inventory,
  plan: RunPlan,
  instance: string,
  leases: ReadonlyArray<NodeLease>
): Effect.Effect<void, CommandError, ProcessRunner> =>
  Effect.gen(function* () {
    while (true) {
      yield* Effect.sleep("10 seconds")
      yield* checkLeases(leases)
      const statuses = yield* Effect.forEach(
        plan.nodes,
        (node) => statusNode(inventory, instance, node),
        { concurrency: "unbounded" }
      )
      const unavailable = statuses.filter(
        (status) => status.activeState !== "active"
      )
      if (unavailable.length > 0) {
        return yield* Effect.fail(
          new CommandError({
            code: "cluster-node-unavailable",
            message: "A clustered inference node is no longer active",
            details: { nodes: unavailable }
          })
        )
      }
    }
  })

export const runCluster = (
  name: string
): Effect.Effect<
  void,
  CommandError,
  FileSystem.FileSystem | LocalLock | ProcessRunner
> =>
  Effect.gen(function* () {
    const prepared = yield* prepareInstance(name)
    yield* runPreparedCluster(name, prepared.inventory, prepared.plan)
  })

export const runPreparedCluster = (
  name: string,
  inventory: Inventory,
  plan: RunPlan
): Effect.Effect<void, CommandError, ProcessRunner> =>
  Effect.gen(function* () {
    if (inventory.localNode !== inventory.controlNode) {
      return yield* Effect.fail(
        new CommandError({
          code: "control-node-required",
          message: `Cluster coordination must run on '${inventory.controlNode}'`
        })
      )
    }
    if (plan.nodes.length < 2) {
      return yield* Effect.fail(
        new CommandError({
          code: "cluster-instance-required",
          message: `Instance '${name}' is not clustered`
        })
      )
    }

    const remoteNodes = plan.nodes.filter(
      (node) => node !== inventory.localNode
    )
    yield* Effect.forEach(
      remoteNodes,
      (node) =>
        phase(name, `Preparing '${node}'`).pipe(
          Effect.zipRight(remoteAction(inventory, node, "prepare", name))
        ),
      { concurrency: 1, discard: true }
    )

    const stopAll = Effect.forEach(
      [...plan.nodes].reverse(),
      (node) =>
        stopNode(inventory, name, node).pipe(
          Effect.catchAll((error) =>
            phase(name, `Unable to stop '${node}': ${error.message}`)
          )
        ),
      { concurrency: 1, discard: true }
    )

    yield* Effect.scoped(
      Effect.acquireRelease(Effect.void, () => stopAll).pipe(
        Effect.zipRight(
          Effect.gen(function* () {
            let leases: ReadonlyArray<NodeLease> = []
            for (const group of clusterStartGroups(plan)) {
              const launched = yield* Effect.forEach(
                group,
                (node) =>
                  phase(name, `Starting '${node}'`).pipe(
                    Effect.zipRight(launchNode(inventory, name, node))
                  ),
                { concurrency: "unbounded" }
              )
              leases = [
                ...leases,
                ...launched.filter(Option.isSome).map((lease) => lease.value)
              ]
              yield* checkLeases(leases)
            }
            yield* phase(name, "Waiting for all node units")
            yield* waitUntilReady(inventory, plan, name, leases)
            const runner = yield* ProcessRunner
            yield* runner.run({
              command: "systemd-notify",
              args: [
                "--ready",
                `--status=Cluster is healthy at ${plan.endpoint.healthUrl}`
              ]
            })
            yield* phase(name, `Cluster is healthy at ${plan.endpoint.healthUrl}`)
            yield* monitorCluster(inventory, plan, name, leases)
          })
        )
      )
    )
  })
