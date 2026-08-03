import { spawn, type ChildProcess } from "node:child_process"
import { fileURLToPath } from "node:url"
import { Context, Effect, Layer, Scope } from "effect"
import { CommandError } from "../domain/errors.js"
import { terminateProcess } from "./process-runner.js"

export interface LocalLockService {
  readonly acquire: (
    path: string,
    options?: { readonly nonBlocking?: boolean }
  ) => Effect.Effect<void, CommandError, Scope.Scope>
}

export class LocalLock extends Context.Tag("inference/LocalLock")<
  LocalLock,
  LocalLockService
>() {}

const holder = fileURLToPath(
  new URL("../entrypoints/lock-holder.js", import.meta.url)
)

const startHolder = (
  path: string,
  nonBlocking: boolean
): Effect.Effect<ChildProcess, CommandError> =>
  Effect.async((resume) => {
    let output = ""
    let settled = false
    const child = spawn(
      "flock",
      [
        "--exclusive",
        ...(nonBlocking ? ["--nonblock"] : []),
        path,
        process.execPath,
        holder
      ],
      { stdio: ["pipe", "pipe", "pipe"] }
    )

    child.stdout?.on("data", (chunk: Uint8Array) => {
      if (settled) return
      output += Buffer.from(chunk).toString("utf8")
      if (output.includes("ready\n")) {
        settled = true
        resume(Effect.succeed(child))
      }
    })
    child.once("error", () => {
      if (settled) return
      settled = true
      resume(
        Effect.fail(
          new CommandError({
            code: "local-lock-failed",
            message: `Unable to start flock for '${path}'`,
            details: { path }
          })
        )
      )
    })
    child.once("exit", (code, signal) => {
      if (settled) return
      settled = true
      resume(
        Effect.fail(
          new CommandError({
            code: "local-lock-failed",
            message: `Unable to acquire local model lock '${path}'`,
            details: { path, exitCode: code, signal }
          })
        )
      )
    })

    return settled ? undefined : terminateProcess(child)
  })

const stopHolder = (child: ChildProcess): Effect.Effect<void> =>
  terminateProcess(child)

export const LocalLockLive = Layer.succeed(LocalLock, {
  acquire: (path, options) =>
    Effect.acquireRelease(
      startHolder(path, options?.nonBlocking ?? false),
      stopHolder
    ).pipe(Effect.asVoid)
})
