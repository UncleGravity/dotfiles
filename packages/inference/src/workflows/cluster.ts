import { FileSystem } from "effect"
import {
  Duration,
  Effect,
  Result,
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
import { emitProgress } from "../observability/progress.js"
import { prepareInstance } from "./instance.js"
import { readUnitStatus } from "./remote.js"

type NodeAction = "prepare" | "lease" | "stop" | "status"

interface NodeLease {
  readonly node: string
  readonly fiber: Fiber.Fiber<void, CommandError>
}

const coordinationIdentityVariable = "INFER_COORDINATION_IDENTITY_FILE"
const sshKnownHosts = "/etc/ssh/ssh_known_hosts"
const remotePreparationConcurrency = 3

export const resolveCoordinationIdentity = (
  path: string | undefined
): Effect.Effect<string, CommandError> => {
  return path !== undefined && path.startsWith("/")
    ? Effect.succeed(path)
    : Effect.fail(
        new CommandError({
          code: "coordination-identity-missing",
          message: `${coordinationIdentityVariable} must name an absolute path`
        })
      )
}

const phase = (
  instance: string,
  operation: string,
  state: "started" | "completed" | "failed" | "warning",
  message: string,
  node?: string
): Effect.Effect<void> =>
  emitProgress({
    kind: "lifecycle",
    scope: "cluster",
    operation,
    state,
    message,
    instance,
    ...(node === undefined ? {} : { node })
  })

const findNode = (inventory: Inventory, name: string) =>
  inventory.nodes.find((candidate) => candidate.name === name)

const remoteArguments = (
  inventory: Inventory,
  nodeName: string,
  action: NodeAction,
  instance: string
): Effect.Effect<ReadonlyArray<string>, CommandError> =>
  Effect.gen(function* () {
    const identity = yield* resolveCoordinationIdentity(
      process.env[coordinationIdentityVariable]
    )
    const node = findNode(inventory, nodeName)
    const address = node?.fabric.fabric0
    if (address === undefined) {
      return yield* Effect.fail(
        new CommandError({
          code: "cluster-node-unreachable",
          message: `Node '${nodeName}' has no fabric0 address`,
          details: { node: nodeName }
        })
      )
    }
    return [
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
        identity,
        `infer-remote@${address}`,
        `${action} ${instance}`
      ]
  })

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
  }).pipe(
    Effect.withSpan("inference.cluster.remote-action", {
      attributes: {
        "inference.action": action,
        "inference.instance": instance,
        "inference.node": node
      }
    })
  )

export const decodeRemoteStatus = (
  raw: string,
  node: string,
  instance: string
): Result.Result<RemoteUnitStatus, CommandError> => {
  const decoded = decodeStrictJson(RemoteUnitStatus, raw).pipe(
    Result.mapError(
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
  if (Result.isFailure(decoded)) return decoded
  if (decoded.success.node !== node || decoded.success.instance !== instance) {
    return Result.fail(
      new CommandError({
        code: "cluster-status-identity-mismatch",
        message: `Node '${node}' returned status for a different cluster unit`,
        details: {
          expected: { node, instance },
          actual: {
            node: decoded.success.node,
            instance: decoded.success.instance
          }
        }
      })
    )
  }
  return decoded
}

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
        return yield* Effect.fromResult(
          decodeRemoteStatus(result.stdout.trim(), node, instance)
        )
      })

const checkLeases = (
  leases: ReadonlyArray<NodeLease>
): Effect.Effect<void, CommandError> =>
  Effect.forEach(
    leases,
    ({ node, fiber }) =>
      Effect.sync(() => fiber.pollUnsafe()).pipe(
        Effect.flatMap((exit) =>
          exit === undefined
            ? Effect.void
            : Fiber.join(fiber).pipe(
                Effect.result,
                Effect.flatMap((result) =>
                  Effect.fail(
                    new CommandError({
                      code: "cluster-lease-lost",
                      message: `The controller lease to '${node}' ended`,
                      details: {
                        node,
                        result: Result.isFailure(result)
                          ? result.failure.message
                          : "remote command exited"
                      }
                    })
                  )
                )
              )
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

const statusSignature = (status: RemoteUnitStatus): string =>
  [
    status.loadState,
    status.activeState,
    status.subState,
    status.result
  ].join("\u0000")

const nodeRole = (
  plan: RunPlan,
  status: RemoteUnitStatus
): "head" | "worker" => (status.node === plan.head ? "head" : "worker")

const readinessMessage = (
  plan: RunPlan,
  status: RemoteUnitStatus,
  unavailable: boolean
): string => {
  const role = nodeRole(plan, status)
  const label = role === "head" ? "Head" : "Worker"
  if (unavailable && !failedStatus(status)) {
    return `${label} became unavailable (${status.activeState}/${status.subState})`
  }
  if (status.loadState !== "loaded") {
    return `${label} unit load state is '${status.loadState}'`
  }
  if (status.activeState === "failed") {
    return `${label} unit failed with result '${status.result}'`
  }
  if (status.activeState === "active") return `${label} is ready`
  if (status.activeState === "activating") {
    return role === "head"
      ? "Waiting for head API health"
      : "Waiting for worker readiness"
  }
  return `${label} unit has not reached readiness`
}

const emitNodeReadiness = (
  plan: RunPlan,
  instance: string,
  status: RemoteUnitStatus,
  unavailable = false
): Effect.Effect<void> =>
  emitProgress({
    kind: "lifecycle",
    scope: "cluster",
    operation: "node-readiness",
    state: unavailable || failedStatus(status)
      ? "failed"
      : status.activeState === "active"
        ? "completed"
        : "started",
    message: readinessMessage(plan, status, unavailable),
    instance,
    node: status.node,
    attributes: {
      role: nodeRole(plan, status),
      loadState: status.loadState,
      activeState: status.activeState,
      subState: status.subState,
      result: status.result
    }
  })

const waitingMessage = (
  statuses: ReadonlyArray<RemoteUnitStatus>
): string => {
  const waiting = statuses.filter((status) => status.activeState !== "active")
  return waiting.length === 0
    ? "All node units are ready"
    : `Waiting for ${waiting
        .map(
          (status) =>
            `${status.node} (${status.activeState}/${status.subState})`
        )
        .join(", ")}`
}

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
    let previousStatuses = new Map<string, string>()
    return Effect.gen(function* () {
      while (true) {
        yield* checkLeases(leases)
        const polled = yield* Effect.forEach(
          plan.nodes,
          (node) => statusNode(inventory, instance, node),
          { concurrency: "unbounded" }
        )
        latest = [...polled].sort(
          (left, right) =>
            plan.nodes.indexOf(left.node) - plan.nodes.indexOf(right.node)
        )
        const ready = latest.filter(
          (status) => status.activeState === "active"
        ).length
        const changed = latest.filter(
          (status) =>
            previousStatuses.get(status.node) !== statusSignature(status)
        )
        if (changed.length > 0) {
          yield* Effect.forEach(
            changed,
            (status) => emitNodeReadiness(plan, instance, status),
            { concurrency: 1, discard: true }
          )
          previousStatuses = new Map(
            latest.map((status) => [status.node, statusSignature(status)])
          )
          yield* emitProgress({
            kind: "progress",
            scope: "cluster",
            operation: "wait-for-nodes",
            message: waitingMessage(latest),
            instance,
            current: ready,
            total: plan.nodes.length,
            unit: "nodes"
          })
        }
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
      Effect.timeoutOrElse({
        duration: Duration.seconds(plan.endpoint.startupTimeoutSeconds),
        orElse: () =>
          Effect.fail(
            new CommandError({
              code: "cluster-startup-timeout",
              message: "The clustered inference instance did not become ready",
              details: { statuses: latest }
            })
          )
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
        yield* Effect.forEach(
          unavailable,
          (status) => emitNodeReadiness(plan, instance, status, true),
          { concurrency: 1, discard: true }
        )
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
  }).pipe(
    Effect.tapError((error) =>
      phase(name, "pipeline", "failed", error.message)
    ),
    Effect.withSpan("inference.run-cluster", {
      attributes: { "inference.instance": name }
    })
  )

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
        phase(name, "prepare-node", "started", `Preparing '${node}'`, node).pipe(
          Effect.andThen(remoteAction(inventory, node, "prepare", name)),
          Effect.tap(() =>
            phase(name, "prepare-node", "completed", `Prepared '${node}'`, node)
          ),
          Effect.tapError((error) =>
            phase(
              name,
              "prepare-node",
              "failed",
              `Unable to prepare '${node}': ${error.message}`,
              node
            )
          )
        ),
      { concurrency: remotePreparationConcurrency, discard: true }
    )

    const stopAll = Effect.forEach(
      [...plan.nodes].reverse(),
      (node) =>
        phase(name, "stop-node", "started", `Stopping '${node}'`, node).pipe(
          Effect.andThen(stopNode(inventory, name, node)),
          Effect.tap(() =>
            phase(name, "stop-node", "completed", `Stopped '${node}'`, node)
          ),
          Effect.catch((error) =>
            phase(
              name,
              "stop-node",
              "warning",
              `Unable to stop '${node}': ${error.message}`,
              node
            )
          )
        ),
      { concurrency: 1, discard: true }
    )

    yield* Effect.scoped(
      Effect.acquireRelease(Effect.void, () => stopAll).pipe(
        Effect.andThen(
          Effect.gen(function* () {
            let leases: ReadonlyArray<NodeLease> = []
            for (const group of clusterStartGroups(plan)) {
              const launched = yield* Effect.forEach(
                group,
                (node) =>
                  phase(
                    name,
                    "start-node",
                    "started",
                    `Requesting launch for '${node}'`,
                    node
                  ).pipe(
                    Effect.andThen(launchNode(inventory, name, node)),
                    Effect.tap(() =>
                      phase(
                        name,
                        "start-node",
                        "completed",
                        `Launch accepted for '${node}'`,
                        node
                      )
                    ),
                    Effect.tapError((error) =>
                      phase(
                        name,
                        "start-node",
                        "failed",
                        `Unable to start '${node}': ${error.message}`,
                        node
                      )
                    )
                  ),
                { concurrency: "unbounded" }
              )
              leases = [
                ...leases,
                ...launched.filter(Option.isSome).map((lease) => lease.value)
              ]
              yield* checkLeases(leases)
            }
            yield* phase(
              name,
              "wait-for-nodes",
              "started",
              "Waiting for all node units"
            )
            yield* waitUntilReady(inventory, plan, name, leases).pipe(
              Effect.tapError((error) =>
                phase(
                  name,
                  "wait-for-nodes",
                  "failed",
                  error.message
                )
              )
            )
            const runner = yield* ProcessRunner
            yield* runner.run({
              command: "systemd-notify",
              args: [
                "--ready",
                `--status=Cluster is healthy at ${plan.endpoint.healthUrl}`
              ]
            })
            yield* phase(
              name,
              "wait-for-nodes",
              "completed",
              `Cluster is healthy at ${plan.endpoint.healthUrl}`
            )
            yield* monitorCluster(inventory, plan, name, leases)
          })
        )
      )
    )
  }).pipe(
    Effect.withSpan("inference.run-prepared-cluster", {
      attributes: {
        "inference.instance": name,
        "inference.node.count": plan.nodes.length
      }
    })
  )
