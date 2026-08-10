#!/usr/bin/env node

import { Effect } from "effect"
import {
  requireSingleArgument,
  runInferenceMain
} from "../runtime/system.js"
import { runCluster } from "../workflows/cluster.js"

runInferenceMain(
  requireSingleArgument(
    process.argv.slice(2),
    "infer-cluster",
    "invalid-cluster-command"
  ).pipe(Effect.flatMap(runCluster))
)
