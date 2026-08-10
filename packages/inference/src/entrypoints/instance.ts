#!/usr/bin/env node

import { Effect } from "effect"
import {
  requireSingleArgument,
  runInferenceMain
} from "../runtime/system.js"
import { runInstance } from "../workflows/instance.js"

runInferenceMain(
  requireSingleArgument(
    process.argv.slice(2),
    "infer-instance",
    "invalid-instance-command"
  ).pipe(Effect.flatMap(runInstance))
)
