import * as NodeRuntime from "@effect/platform-node/NodeRuntime"
import * as NodeServices from "@effect/platform-node/NodeServices"
import { Effect, Layer } from "effect"
import { HealthProbe, HealthProbeLive } from "../adapters/health-probe.js"
import { LocalLock, LocalLockLive } from "../adapters/local-lock.js"
import { ProcessRunner, ProcessRunnerLive } from "../adapters/process-runner.js"
import { CommandError } from "../domain/errors.js"

export const InferenceToolsLive = Layer.mergeAll(
  ProcessRunnerLive,
  LocalLockLive
)

const InferenceRuntimeLive = Layer.mergeAll(
  NodeServices.layer,
  HealthProbeLive,
  InferenceToolsLive
)

type InferenceRuntimeServices =
  | NodeServices.NodeServices
  | HealthProbe
  | LocalLock
  | ProcessRunner

export const runInferenceMain = <A, E>(
  program: Effect.Effect<A, E, InferenceRuntimeServices>
): void => {
  program.pipe(Effect.provide(InferenceRuntimeLive), NodeRuntime.runMain)
}

export const requireSingleArgument = (
  args: ReadonlyArray<string>,
  executable: string,
  errorCode: string
): Effect.Effect<string, CommandError> =>
  args.length === 1 && args[0] !== undefined
    ? Effect.succeed(args[0])
    : Effect.fail(
        new CommandError({
          code: errorCode,
          message: `${executable} requires exactly one instance name`
        })
      )
