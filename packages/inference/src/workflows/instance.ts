import { FileSystem } from "@effect/platform"
import { Console, Duration, Effect, Fiber, Option } from "effect"
import { loadContract } from "../adapters/contract-files.js"
import { HealthProbe } from "../adapters/health-probe.js"
import { LocalLock } from "../adapters/local-lock.js"
import { ProcessRunner } from "../adapters/process-runner.js"
import {
  Catalog,
  InstanceCatalog,
  Inventory,
  type InstanceDeclaration,
  type NodePlan,
  type RunPlan
} from "../domain/contracts.js"
import { CommandError } from "../domain/errors.js"
import { resolveInstancePlan } from "../domain/planner.js"
import { ensureImage } from "./image-store.js"
import { ensureLocalModel } from "./model-store.js"

interface PreparedImage {
  readonly reference: string
  readonly digest: string
}

const containerName = (instance: string): string => `infer-${instance}`

const phase = (instance: string, message: string): Effect.Effect<void> =>
  Console.error(`[infer:${instance}] ${message}`)

export const containerArguments = (
  instance: InstanceDeclaration,
  plan: RunPlan,
  nodePlan: NodePlan,
  image: PreparedImage,
  invocationId?: string
): ReadonlyArray<string> => {
  const container = nodePlan.container
  const devices = container.devices.flatMap((device) => ["--device", device])
  const environment = Object.entries(container.environment)
    .sort(([left], [right]) => left.localeCompare(right))
    .flatMap(([name, value]) => ["--env", `${name}=${value}`])
  const mounts = container.mounts.flatMap((mount) => [
    "--volume",
    `${mount.sourcePath}:${mount.targetPath}:${mount.readOnly ? "ro" : "rw"}`
  ])
  const labels = [
    `io.angel.infer.instance=${instance.name}`,
    `io.angel.infer.recipe=${plan.recipe.name}`,
    `io.angel.infer.recipe-hash=${plan.recipe.hash}`,
    `io.angel.infer.image-digest=${image.digest}`,
    `io.angel.infer.role=${nodePlan.role}`,
    ...(invocationId === undefined
      ? []
      : [`io.angel.infer.invocation-id=${invocationId}`])
  ].flatMap((label) => ["--label", label])

  return [
    "run",
    "--rm",
    "--pull=never",
    "--log-driver=none",
    "--cgroups=disabled",
    "--name",
    containerName(instance.name),
    "--network",
    container.network,
    ...labels,
    ...devices,
    ...container.extraOptions,
    ...environment,
    ...mounts,
    image.reference,
    ...container.args
  ]
}

const failIfExited = (
  container: Fiber.Fiber<void, CommandError>
): Effect.Effect<void, CommandError> =>
  Fiber.poll(container).pipe(
    Effect.flatMap(
      Option.match({
        onNone: () => Effect.void,
        onSome: () =>
          Fiber.await(container).pipe(
            Effect.zipRight(
              Effect.fail(
                new CommandError({
                  code: "container-exited",
                  message: "The inference container exited unexpectedly"
                })
              )
            )
          )
      })
    )
  )

export const waitUntilHealthy = (
  plan: RunPlan,
  container: Fiber.Fiber<void, CommandError>
): Effect.Effect<void, CommandError, HealthProbe> =>
  Effect.gen(function* () {
    const health = yield* HealthProbe
    let successes = 0
    while (successes < 2) {
      yield* failIfExited(container)
      successes = (yield* health.reachable(plan.endpoint.healthUrl))
        ? successes + 1
        : 0
      if (successes >= 2) break
      yield* Effect.sleep("2 seconds")
    }
  }).pipe(
    Effect.timeoutFail({
      duration: Duration.seconds(plan.endpoint.startupTimeoutSeconds),
      onTimeout: () =>
        new CommandError({
          code: "startup-timeout",
          message: "Inference did not become healthy before its recipe timeout",
          details: { timeoutSeconds: plan.endpoint.startupTimeoutSeconds }
        })
    })
  )

export const monitorHealth = (
  plan: RunPlan,
  container: Fiber.Fiber<void, CommandError>
): Effect.Effect<void, CommandError, HealthProbe> =>
  Effect.gen(function* () {
    const health = yield* HealthProbe
    let failures = 0
    while (true) {
      yield* Effect.sleep("10 seconds")
      yield* failIfExited(container)
      failures = (yield* health.reachable(plan.endpoint.healthUrl))
        ? 0
        : failures + 1
      if (failures >= 3) {
        return yield* Effect.fail(
          new CommandError({
            code: "endpoint-unhealthy",
            message: "The inference endpoint failed three consecutive checks"
          })
        )
      }
    }
  })

const monitorContainer = (
  container: Fiber.Fiber<void, CommandError>
): Effect.Effect<void, CommandError> =>
  Effect.gen(function* () {
    while (true) {
      yield* Effect.sleep("10 seconds")
      yield* failIfExited(container)
    }
  })

const localNodePlan = (
  plan: RunPlan,
  inventory: Inventory
): Effect.Effect<NodePlan, CommandError> => {
  const nodePlan = plan.nodePlans.find(
    (candidate) => candidate.node === inventory.localNode
  )
  return nodePlan === undefined
    ? Effect.fail(
        new CommandError({
          code: "instance-not-allocated-locally",
          message: `Instance is not allocated to '${inventory.localNode}'`,
          details: {
            localNode: inventory.localNode,
            nodes: plan.nodes
          }
        })
      )
    : Effect.succeed(nodePlan)
}

export interface PreparedInstance {
  readonly declaration: InstanceDeclaration
  readonly inventory: Inventory
  readonly plan: RunPlan
  readonly image: PreparedImage
}

export const prepareInstance = (
  name: string
): Effect.Effect<
  PreparedInstance,
  CommandError,
  FileSystem.FileSystem | LocalLock | ProcessRunner
> =>
  Effect.gen(function* () {
    yield* phase(name, "Loading deployment contracts")
    const [catalog, inventory, instances] = yield* Effect.all([
      loadContract("/etc/infer/catalog.json", "Catalog", Catalog),
      loadContract("/etc/infer/inventory.json", "Inventory", Inventory),
      loadContract(
        "/etc/infer/instances.json",
        "InstanceCatalog",
        InstanceCatalog
      )
    ])
    const { declaration, plan } = yield* resolveInstancePlan(
      catalog.value,
      inventory.value,
      inventory.raw,
      instances.value,
      name
    )
    yield* phase(
      name,
      `Prepared plan for recipe '${declaration.recipe}' on '${inventory.value.localNode}'`
    )
    const modelSource =
      inventory.value.localNode === inventory.value.controlNode
        ? undefined
        : inventory.value.controlNode
    yield* Effect.forEach(plan.models, (model) =>
      Effect.gen(function* () {
        yield* phase(
          name,
          `Ensuring model '${model.name}' (${model.artifact.repo}@${model.artifact.revision})`
        )
        yield* ensureLocalModel(inventory.value, model.artifact, modelSource)
        yield* phase(name, `Model '${model.name}' is ready`)
      })
    )
    yield* phase(name, `Ensuring image for recipe '${declaration.recipe}'`)
    const imageStatus = yield* ensureImage(
      catalog.value,
      inventory.value,
      declaration.recipe
    )
    const image = {
      reference: imageStatus.local.reference,
      digest: imageStatus.registry.digest
    }
    yield* phase(name, `Image is ready at ${image.reference}`)
    return { declaration, inventory: inventory.value, plan, image }
  })

export const runInstance = (
  name: string
): Effect.Effect<
  void,
  CommandError,
  FileSystem.FileSystem | HealthProbe | LocalLock | ProcessRunner
> =>
  Effect.gen(function* () {
    const prepared = yield* prepareInstance(name)
    yield* runPreparedInstance(name, prepared, process.env.INVOCATION_ID)
  })

export const runPreparedInstance = (
  name: string,
  prepared: PreparedInstance,
  invocationId?: string
): Effect.Effect<void, CommandError, HealthProbe | ProcessRunner> =>
  Effect.gen(function* () {
    const { declaration, inventory, plan, image } = prepared
    const nodePlan = yield* localNodePlan(plan, inventory)
    const args = containerArguments(
      declaration,
      plan,
      nodePlan,
      image,
      invocationId
    )

    yield* Effect.scoped(
      Effect.gen(function* () {
        yield* phase(name, `Launching container '${containerName(name)}'`)
        const runner = yield* ProcessRunner
        const container = yield* Effect.forkScoped(
          runner.foreground({ command: "podman", args })
        )
        if (nodePlan.role === "worker") {
          yield* Effect.sleep("2 seconds")
          yield* failIfExited(container)
          yield* runner.run({
            command: "systemd-notify",
            args: ["--ready", "--status=Worker container is running"]
          })
          yield* phase(name, "Monitoring worker container")
          yield* monitorContainer(container)
        } else {
          yield* phase(
            name,
            `Waiting for ${plan.endpoint.healthUrl} to become healthy`
          )
          yield* waitUntilHealthy(plan, container)
          yield* phase(
            name,
            `Endpoint is healthy at ${plan.endpoint.healthUrl}`
          )
          yield* runner.run({
            command: "systemd-notify",
            args: [
              "--ready",
              `--status=Healthy at ${plan.endpoint.healthUrl}`
            ]
          })
          yield* phase(name, "Monitoring container and endpoint health")
          yield* monitorHealth(plan, container)
        }
      })
    )
  })
