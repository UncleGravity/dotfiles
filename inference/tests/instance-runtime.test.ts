import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import { Effect, Schema } from "effect"
import {
  InstanceCatalog,
  RunPlan
} from "../src/domain/contracts.js"
import {
  ProcessRunner,
  ProcessRunnerLive
} from "../src/adapters/process-runner.js"
import { containerArguments } from "../src/workflows/instance.js"
import { clusterStartGroups } from "../src/workflows/cluster.js"

const contracts = "tests/fixtures/contracts/v1"
const plan = Schema.decodeUnknownSync(RunPlan)(
  JSON.parse(readFileSync(`${contracts}/run-plan.json`, "utf8"))
)
const instances = Schema.decodeUnknownSync(InstanceCatalog)(
  JSON.parse(readFileSync(`${contracts}/instances.json`, "utf8"))
)

test("an instance plan becomes one shell-free Podman argv", () => {
  const image = {
    reference: `registry.example/infer/fixture@sha256:${"d".repeat(64)}`,
    digest: `sha256:${"d".repeat(64)}`
  }
  const args = containerArguments(
    instances.instances[0]!,
    plan,
    plan.nodePlans[0]!,
    image,
    "invocation-id"
  )
  assert.deepEqual(args.slice(0, 11), [
    "run",
    "--rm",
    "--pull=never",
    "--log-driver=none",
    "--cgroups=disabled",
    "--name",
    "infer-fixture",
    "--network",
    "host",
    "--label",
    "io.angel.infer.instance=fixture"
  ])
  assert.ok(args.includes("io.angel.infer.invocation-id=invocation-id"))
  assert.ok(args.includes("nvidia.com/gpu=all"))
  assert.ok(args.includes("--volume"))
  assert.ok(args.includes(image.reference))
  assert.deepEqual(args.slice(-3), [
    "/models/target",
    "--served-model-name",
    "fixture"
  ])
})

test("container mounts preserve explicit writable access", () => {
  const writablePlan = Schema.decodeUnknownSync(RunPlan)({
    ...plan,
    nodePlans: plan.nodePlans.map((nodePlan, index) =>
      index === 0
        ? {
            ...nodePlan,
            container: {
              ...nodePlan.container,
              mounts: [
                ...nodePlan.container.mounts,
                {
                  sourcePath: "/var/cache/fixture",
                  targetPath: "/root/.cache",
                  readOnly: false
                }
              ]
            }
          }
        : nodePlan
    )
  })
  const image = {
    reference: `registry.example/infer/fixture@sha256:${"d".repeat(64)}`,
    digest: `sha256:${"d".repeat(64)}`
  }
  const args = containerArguments(
    instances.instances[0]!,
    writablePlan,
    writablePlan.nodePlans[0]!,
    image
  )

  assert.ok(args.includes("/var/cache/fixture:/root/.cache:rw"))
  assert.ok(args.some((argument) => argument.endsWith(":ro")))
})

test("container arguments select the requested worker plan", () => {
  const image = {
    reference: `registry.example/infer/fixture@sha256:${"d".repeat(64)}`,
    digest: `sha256:${"d".repeat(64)}`
  }
  const worker = plan.nodePlans.find((nodePlan) => nodePlan.role === "worker")
  assert.ok(worker)

  const args = containerArguments(
    instances.instances[0]!,
    plan,
    worker,
    image
  )
  assert.ok(args.includes("io.angel.infer.role=worker"))
  assert.ok(args.includes("INFER_ROLE=worker"))
  assert.ok(args.includes(`INFER_NODE=${worker.node}`))
})

test("cluster start groups preserve the declared role order", () => {
  assert.deepEqual(clusterStartGroups(plan), [
    plan.nodes.filter((node) => node !== plan.head),
    [plan.head]
  ])
  assert.deepEqual(clusterStartGroups({ ...plan, startOrder: "head-first" }), [
    [plan.head],
    plan.nodes.filter((node) => node !== plan.head)
  ])
  assert.deepEqual(clusterStartGroups({ ...plan, startOrder: "parallel" }), [
    plan.nodes
  ])
})

test("process input tolerates a child closing stdin early", async () => {
  const outcome = await Effect.runPromise(
    Effect.gen(function* () {
      const runner = yield* ProcessRunner
      return yield* runner.probe({
        command: "true",
        args: [],
        input: "x".repeat(1024 * 1024)
      })
    }).pipe(Effect.provide(ProcessRunnerLive))
  )
  assert.equal(outcome.exitCode, 0)
})
