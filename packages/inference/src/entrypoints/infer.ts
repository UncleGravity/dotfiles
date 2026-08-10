#!/usr/bin/env node

import { Command } from "effect/unstable/cli"
import { inferCommand } from "../cli/infer.js"
import { runCli } from "../runtime/run-cli.js"

const cli = Command.runWith(inferCommand, {
  version: "0.1.0"
})

runCli(cli(process.argv.slice(2)))
