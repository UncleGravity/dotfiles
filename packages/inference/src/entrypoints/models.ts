#!/usr/bin/env node

import { Command } from "effect/unstable/cli"
import { Effect } from "effect"
import { modelsCommand } from "../cli/models.js"
import { runCli } from "../runtime/run-cli.js"
import { InferenceToolsLive } from "../runtime/system.js"

const cli = Command.runWith(modelsCommand, {
  version: "0.1.0"
})

runCli(cli(process.argv.slice(2)).pipe(Effect.provide(InferenceToolsLive)))
