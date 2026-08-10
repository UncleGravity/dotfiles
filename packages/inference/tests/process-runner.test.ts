import assert from "node:assert/strict"
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import * as path from "node:path"
import test from "node:test"
import { Effect, Result, Fiber } from "effect"
import {
  ProcessRunner,
  ProcessRunnerLive
} from "../src/adapters/process-runner.js"

const node = (source: string) => ({
  command: process.execPath,
  args: ["--eval", source]
})

const run = <A, E>(effect: Effect.Effect<A, E, ProcessRunner>): Promise<A> =>
  Effect.runPromise(effect.pipe(Effect.provide(ProcessRunnerLive)))

const waitForFile = (target: string): Effect.Effect<void, unknown> =>
  Effect.gen(function* () {
    while (!existsSync(target)) yield* Effect.sleep("5 millis")
  }).pipe(Effect.timeout("2 seconds"), Effect.asVoid)

test("process runner captures output and reports nonzero exits", async () => {
  const success = await run(
    Effect.gen(function* () {
      const runner = yield* ProcessRunner
      return yield* runner.run(
        node('process.stdout.write("out"); process.stderr.write("err")')
      )
    })
  )
  assert.deepEqual(success, { stdout: "out", stderr: "err" })

  const failure = await run(
    Effect.gen(function* () {
      const runner = yield* ProcessRunner
      return yield* Effect.result(
        runner.run(node('process.stderr.write("bad"); process.exit(7)'))
      )
    })
  )
  assert.ok(Result.isFailure(failure))
  assert.equal(failure.failure.code, "external-command-failed")
  assert.deepEqual(failure.failure.details, {
    command: process.execPath,
    exitCode: 7,
    signal: null,
    stderr: "bad"
  })
})

test("process runner reports spawn failures", async () => {
  const result = await run(
    Effect.gen(function* () {
      const runner = yield* ProcessRunner
      return yield* Effect.result(
        runner.run({
          command: "/definitely/not/an/inference-command",
          args: []
        })
      )
    })
  )
  assert.ok(Result.isFailure(result))
  assert.equal(result.failure.code, "external-command-start-failed")
})

test("foreground process reports unsuccessful exits", async () => {
  const result = await run(
    Effect.gen(function* () {
      const runner = yield* ProcessRunner
      return yield* Effect.result(
        runner.foreground(node("process.exit(9)"))
      )
    })
  )
  assert.ok(Result.isFailure(result))
  assert.equal(result.failure.code, "external-command-failed")
  assert.deepEqual(result.failure.details, {
    command: process.execPath,
    exitCode: 9,
    signal: null
  })
})

test("process output preserves split UTF-8 and stays bounded", async () => {
  const split = await run(
    Effect.gen(function* () {
      const runner = yield* ProcessRunner
      return yield* runner.run(
        node(`
          process.stdout.write(Buffer.from([0xe2]))
          setTimeout(() => process.stdout.write(Buffer.from([0x82, 0xac])), 10)
        `)
      )
    })
  )
  assert.equal(split.stdout, "€")

  const bounded = await run(
    Effect.gen(function* () {
      const runner = yield* ProcessRunner
      return yield* runner.run(
        node('process.stdout.write("a".repeat(70000) + "tail")')
      )
    })
  )
  assert.equal(bounded.stdout.length, 64 * 1024)
  assert.equal(bounded.stdout.endsWith("tail"), true)
})

test("interrupting a foreground process terminates the child", async () => {
  const temporary = mkdtempSync(path.join(tmpdir(), "inference-process-"))
  const started = path.join(temporary, "started")
  const terminated = path.join(temporary, "terminated")

  try {
    await run(
      Effect.gen(function* () {
        const runner = yield* ProcessRunner
        const fiber = yield* Effect.forkChild(
          runner.foreground(
            node(`
              const fs = require("node:fs")
              fs.writeFileSync(${JSON.stringify(started)}, "started")
              process.on("SIGTERM", () => {
                fs.writeFileSync(${JSON.stringify(terminated)}, "terminated")
                process.exit(0)
              })
              setInterval(() => {}, 1000)
            `)
          )
        )
        yield* waitForFile(started)
        yield* Fiber.interrupt(fiber)
      })
    )
    assert.equal(readFileSync(terminated, "utf8"), "terminated")
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})
