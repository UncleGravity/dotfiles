#!/usr/bin/env node

import { Command } from "@effect/cli"
import { Effect, Layer } from "effect"
import { LocalLockLive } from "../adapters/local-lock.js"
import { ProcessRunnerLive } from "../adapters/process-runner.js"
import { modelsCommand } from "../cli/models.js"
import { runCli } from "../runtime/run-cli.js"

const cli = Command.run(modelsCommand, {
  name: "Model store CLI",
  version: "0.1.0"
})

const runtime = Layer.merge(LocalLockLive, ProcessRunnerLive)

runCli(cli(process.argv).pipe(Effect.provide(runtime)))
