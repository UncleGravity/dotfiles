#!/usr/bin/env node

import { Effect } from "effect"
import {
  requireSingleArgument,
  runInferenceMain
} from "../runtime/system.js"
import { prepareInstance } from "../workflows/instance.js"

runInferenceMain(
  requireSingleArgument(
    process.argv.slice(2),
    "infer-prepare",
    "invalid-prepare-command"
  ).pipe(Effect.flatMap((name) => prepareInstance(name)), Effect.asVoid)
)
