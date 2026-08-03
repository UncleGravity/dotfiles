#!/usr/bin/env node

import { NodeContext, NodeRuntime } from "@effect/platform-node"
import { Effect, Layer } from "effect"
import { ProcessRunnerLive } from "../adapters/process-runner.js"
import { CommandError } from "../domain/errors.js"
import { runRemoteCommand } from "../workflows/remote.js"

const originalCommand = process.env.SSH_ORIGINAL_COMMAND
const program =
  originalCommand === undefined
    ? Effect.fail(
        new CommandError({
          code: "missing-remote-command",
          message: "infer-remote must be invoked by its restricted SSH key"
        })
      )
    : runRemoteCommand(originalCommand)

program.pipe(
  Effect.provide(Layer.mergeAll(NodeContext.layer, ProcessRunnerLive)),
  NodeRuntime.runMain
)
