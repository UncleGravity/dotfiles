#!/usr/bin/env node

import { Effect } from "effect"
import { Command } from "effect/unstable/cli"
import { JournalReaderLive } from "../adapters/journal-reader.js"
import { inferCommand } from "../cli/infer.js"
import { runCli } from "../runtime/run-cli.js"

const cli = Command.runWith(inferCommand, {
  version: "0.1.0"
})

runCli(cli(process.argv.slice(2)).pipe(Effect.provide(JournalReaderLive)))
