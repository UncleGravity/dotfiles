#!/usr/bin/env node

import { Command } from "@effect/cli"
import { inferCommand } from "../cli/infer.js"
import { runCli } from "../runtime/run-cli.js"

const cli = Command.run(inferCommand, {
  name: "Inference CLI",
  version: "0.1.0"
})

runCli(cli(process.argv))
