import assert from "node:assert/strict"
import test from "node:test"
import { Effect, Either } from "effect"
import { parseRemoteRequest } from "../src/workflows/remote.js"

test("remote commands accept only one fixed action and declared-name shape", async () => {
  const valid = await Effect.runPromise(parseRemoteRequest("prepare fixture"))
  assert.deepEqual(valid, { action: "prepare", instance: "fixture" })

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
