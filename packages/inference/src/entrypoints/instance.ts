#!/usr/bin/env node

import { NodeContext, NodeRuntime } from "@effect/platform-node"
import { Effect, Layer } from "effect"
import { HealthProbeLive } from "../adapters/health-probe.js"
import { LocalLockLive } from "../adapters/local-lock.js"
import { ProcessRunnerLive } from "../adapters/process-runner.js"
import { CommandError } from "../domain/errors.js"
import { runInstance } from "../workflows/instance.js"

const name = process.argv[2]
const program =
  name === undefined || process.argv.length !== 3
    ? Effect.fail(
        new CommandError({
          code: "invalid-instance-command",
          message: "infer-instance requires exactly one instance name"
        })
      )
    : runInstance(name)

program.pipe(
  Effect.provide(
    Layer.mergeAll(
      NodeContext.layer,
      HealthProbeLive,
      ProcessRunnerLive,
      LocalLockLive
    )
  ),
  NodeRuntime.runMain
)
