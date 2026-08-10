#!/usr/bin/env node

import { Effect } from "effect"
import { CommandError } from "../domain/errors.js"
import { runInferenceMain } from "../runtime/system.js"
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

runInferenceMain(program)
