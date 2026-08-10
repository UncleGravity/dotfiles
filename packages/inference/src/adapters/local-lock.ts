import { fileURLToPath } from "node:url"
import * as NodeServices from "@effect/platform-node/NodeServices"
import { Context, Effect, Layer, Option, Scope, Stream } from "effect"
import { ChildProcess, ChildProcessSpawner } from "effect/unstable/process"
import { CommandError } from "../domain/errors.js"

export interface LocalLockService {
  readonly acquire: (
    path: string,
    options?: { readonly nonBlocking?: boolean }
  ) => Effect.Effect<void, CommandError, Scope.Scope>
}

export class LocalLock extends Context.Service<LocalLock, LocalLockService>()(
  "inference/LocalLock"
) {}

const holder = fileURLToPath(
  new URL("../entrypoints/lock-holder.js", import.meta.url)
)

const makeLocalLock = Effect.gen(function* () {
  const spawner = yield* ChildProcessSpawner.ChildProcessSpawner

  return LocalLock.of({
    acquire: (path, options) =>
      Effect.gen(function* () {
        const command = ChildProcess.make(
          "flock",
          [
            "--exclusive",
            ...(options?.nonBlocking === true ? ["--nonblock"] : []),
            path,
            process.execPath,
            holder
          ],
          {
            detached: false,
            forceKillAfter: "5 seconds",
            stdin: "pipe",
            stdout: "pipe",
            stderr: "pipe"
          }
        )
        const handle = yield* spawner.spawn(command).pipe(
          Effect.mapError(
            () =>
              new CommandError({
                code: "local-lock-failed",
                message: `Unable to start flock for '${path}'`,
                details: { path }
              })
          )
        )
        const ready = yield* handle.stdout.pipe(
          Stream.decodeText,
          Stream.splitLines,
          Stream.runHead,
          Effect.mapError(
            () =>
              new CommandError({
                code: "local-lock-failed",
                message: `Unable to read flock handshake for '${path}'`,
                details: { path }
              })
          )
        )
        if (Option.getOrUndefined(ready) === "ready") return

        const exitCode = yield* handle.exitCode.pipe(
          Effect.mapError(
            () =>
              new CommandError({
                code: "local-lock-failed",
                message: `Unable to inspect flock for '${path}'`,
                details: { path }
              })
          )
        )
        return yield* Effect.fail(
          new CommandError({
            code: "local-lock-failed",
            message: `Unable to acquire local model lock '${path}'`,
            details: { path, exitCode: Number(exitCode), signal: null }
          })
        )
      })
  })
})

export const LocalLockLive = Layer.effect(LocalLock, makeLocalLock).pipe(
  Layer.provide(NodeServices.layer)
)
