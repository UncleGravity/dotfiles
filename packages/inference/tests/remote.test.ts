import assert from "node:assert/strict"
import test from "node:test"
import { Effect, Either, Layer } from "effect"
import {
  ProcessRunner,
  type ProcessRequest,
  type ProcessRunnerService
} from "../src/adapters/process-runner.js"
import {
  parseRemoteRequest,
  readUnitStatus
} from "../src/workflows/remote.js"

test("remote commands accept only one fixed action and declared-name shape", async () => {
  for (const action of ["prepare", "lease", "stop", "status"] as const) {
    const valid = await Effect.runPromise(
      parseRemoteRequest(`${action} fixture`)
    )
    assert.deepEqual(valid, { action, instance: "fixture" })
  }

  for (const command of [
    "start fixture",
    "restart fixture",
    "start fixture extra",
    "start fixture;systemctl reboot",
    "status ../fixture",
    ""
  ]) {
    const result = await Effect.runPromise(
      Effect.either(parseRemoteRequest(command))
    )
    assert.ok(Either.isLeft(result), command)
    assert.equal(result.left.code, "invalid-remote-command")
  }
})

test("unit status uses fixed systemctl properties and preserves values", async () => {
  let request: ProcessRequest | undefined
  const runner: ProcessRunnerService = {
    foreground: () => Effect.die("unexpected foreground command"),
    probe: () => Effect.die("unexpected probe command"),
    run: (value) => {
      request = value
      return Effect.succeed({
        stdout: [
          "LoadState=loaded",
          "ActiveState=failed",
          "SubState=failed",
          "Result=exit-code=1",
          "ignored-line"
        ].join("\n"),
        stderr: ""
      })
    }
  }

  const status = await Effect.runPromise(
    readUnitStatus("fixture", "spark-02", "infer-node-fixture.service").pipe(
      Effect.provide(Layer.succeed(ProcessRunner, runner))
    )
  )
  assert.deepEqual(request, {
    command: "systemctl",
    args: [
      "show",
      "infer-node-fixture.service",
      "--property=LoadState",
      "--property=ActiveState",
      "--property=SubState",
      "--property=Result",
      "--no-pager"
    ]
  })
  assert.deepEqual(status, {
    schemaVersion: 1,
    instance: "fixture",
    node: "spark-02",
    loadState: "loaded",
    activeState: "failed",
    subState: "failed",
    result: "exit-code=1"
  })
})
