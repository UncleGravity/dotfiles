import assert from "node:assert/strict"
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  symlinkSync,
  writeFileSync
} from "node:fs"
import { tmpdir } from "node:os"
import * as path from "node:path"
import test from "node:test"
import { Effect, Result } from "effect"
import { LocalLock, LocalLockLive } from "../src/adapters/local-lock.js"

const fakeFlock = (node: string) => `#!${node}
const { openSync, closeSync, rmSync } = require("node:fs")
const { spawn } = require("node:child_process")

const args = process.argv.slice(2)
if (args.shift() !== "--exclusive") process.exit(64)
const nonBlocking = args[0] === "--nonblock"
if (nonBlocking) args.shift()
const lockPath = args.shift()
const command = args.shift()
const marker = lockPath + ".fake-held"

let descriptor
try {
  descriptor = openSync(marker, "wx")
} catch {
  process.exit(nonBlocking ? 1 : 70)
}
closeSync(descriptor)

const child = spawn(command, args, { stdio: "inherit" })
let finished = false
const finish = (code) => {
  if (finished) return
  finished = true
  rmSync(marker, { force: true })
  process.exit(code ?? 1)
}
child.once("exit", finish)
child.once("error", () => finish(71))
process.once("SIGTERM", () => child.kill("SIGTERM"))
process.once("SIGINT", () => child.kill("SIGINT"))
`

test("local locks reject contention, release, and classify spawn errors", async () => {
  const temporary = mkdtempSync(path.join(tmpdir(), "inference-lock-"))
  const bin = path.join(temporary, "bin")
  const node = path.join(bin, "node")
  const flock = path.join(bin, "flock")
  const lockPath = path.join(temporary, "model.lock")
  const originalPath = process.env.PATH
  mkdirSync(bin)
  symlinkSync(process.execPath, node)
  writeFileSync(flock, fakeFlock(node))
  chmodSync(flock, 0o755)
  process.env.PATH = `${bin}${path.delimiter}${originalPath ?? ""}`

  try {
    const contention = await Effect.runPromise(
      Effect.gen(function* () {
        const lock = yield* LocalLock
        return yield* Effect.scoped(
          lock.acquire(lockPath).pipe(
            Effect.andThen(
              Effect.result(
                Effect.scoped(
                  lock.acquire(lockPath, { nonBlocking: true })
                )
              )
            )
          )
        )
      }).pipe(Effect.provide(LocalLockLive))
    )
    assert.ok(Result.isFailure(contention))
    assert.equal(contention.failure.code, "local-lock-failed")

    await Effect.runPromise(
      Effect.gen(function* () {
        const lock = yield* LocalLock
        yield* Effect.scoped(
          lock.acquire(lockPath, { nonBlocking: true })
        )
      }).pipe(Effect.provide(LocalLockLive))
    )

    process.env.PATH = path.join(temporary, "missing-bin")
    const unavailable = await Effect.runPromise(
      Effect.gen(function* () {
        const lock = yield* LocalLock
        return yield* Effect.result(
          Effect.scoped(lock.acquire(path.join(temporary, "unavailable.lock")))
        )
      }).pipe(Effect.provide(LocalLockLive))
    )
    assert.ok(Result.isFailure(unavailable))
    assert.equal(unavailable.failure.code, "local-lock-failed")
  } finally {
    if (originalPath === undefined) delete process.env.PATH
    else process.env.PATH = originalPath
    rmSync(temporary, { recursive: true, force: true })
  }
})
