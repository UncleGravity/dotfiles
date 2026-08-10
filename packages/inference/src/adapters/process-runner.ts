import * as NodeServices from "@effect/platform-node/NodeServices"
import { Context, Effect, Layer, Stream } from "effect"
import { ChildProcess, ChildProcessSpawner } from "effect/unstable/process"
import { CommandError } from "../domain/errors.js"

export interface ProcessRequest {
  readonly command: string
  readonly args: ReadonlyArray<string>
  readonly environment?: Readonly<Record<string, string>>
  readonly input?: string
}

export interface ProcessResult {
  readonly stdout: string
  readonly stderr: string
}

export interface ProcessOutcome extends ProcessResult {
  readonly exitCode: number | null
  readonly signal: NodeJS.Signals | null
}

export interface ProcessRunnerService {
  readonly foreground: (
    request: ProcessRequest
  ) => Effect.Effect<void, CommandError>
  readonly probe: (
    request: ProcessRequest
  ) => Effect.Effect<ProcessOutcome, CommandError>
  readonly run: (
    request: ProcessRequest
  ) => Effect.Effect<ProcessResult, CommandError>
}

export class ProcessRunner extends Context.Service<
  ProcessRunner,
  ProcessRunnerService
>()("inference/ProcessRunner") {}

const outputLimit = 64 * 1024

const appendOutput = (current: string, chunk: string): string => {
  const next = current + chunk
  return next.length <= outputLimit ? next : next.slice(-outputLimit)
}

const startError = (request: ProcessRequest): CommandError =>
  new CommandError({
    code: "external-command-start-failed",
    message: `Unable to start '${request.command}'`,
    details: { command: request.command }
  })

const failedError = (
  request: ProcessRequest,
  outcome: Pick<ProcessOutcome, "exitCode" | "signal"> &
    Partial<Pick<ProcessOutcome, "stderr">>
): CommandError =>
  new CommandError({
    code: "external-command-failed",
    message: `'${request.command}' exited unsuccessfully`,
    details: {
      command: request.command,
      exitCode: outcome.exitCode,
      signal: outcome.signal,
      ...(outcome.stderr === undefined
        ? {}
        : { stderr: outcome.stderr.trim() })
    }
  })

const command = (
  request: ProcessRequest,
  stdio: "capture" | "inherit"
): ChildProcess.StandardCommand =>
  ChildProcess.make(request.command, request.args, {
    detached: false,
    env: request.environment,
    extendEnv: true,
    forceKillAfter: "5 seconds",
    stdin:
      stdio === "inherit"
        ? "inherit"
        : request.input === undefined
          ? "ignore"
          : Stream.succeed(new TextEncoder().encode(request.input)),
    stdout: stdio === "inherit" ? "inherit" : "pipe",
    stderr: stdio === "inherit" ? "inherit" : "pipe"
  })

const collectOutput = (
  stream: Stream.Stream<Uint8Array, unknown>
): Effect.Effect<string, unknown> =>
  stream.pipe(
    Stream.decodeText,
    Stream.runFold(() => "", (output, chunk) => appendOutput(output, chunk))
  )

const makeProcessRunner = Effect.gen(function* () {
  const spawner = yield* ChildProcessSpawner.ChildProcessSpawner

  const probe = (
    request: ProcessRequest
  ): Effect.Effect<ProcessOutcome, CommandError> =>
    Effect.scoped(
      Effect.gen(function* () {
        const handle = yield* spawner.spawn(command(request, "capture"))
        const [stdout, stderr, exitCode] = yield* Effect.all(
          [
            collectOutput(handle.stdout),
            collectOutput(handle.stderr),
            handle.exitCode
          ],
          { concurrency: "unbounded" }
        )
        return {
          stdout,
          stderr,
          exitCode: Number(exitCode),
          signal: null
        }
      }).pipe(Effect.mapError(() => startError(request)))
    )

  return ProcessRunner.of({
    foreground: (request) =>
      spawner.exitCode(command(request, "inherit")).pipe(
        Effect.mapError(() => startError(request)),
        Effect.flatMap((exitCode) =>
          Number(exitCode) === 0
            ? Effect.void
            : Effect.fail(
                failedError(request, {
                  exitCode: Number(exitCode),
                  signal: null
                })
              )
        )
      ),
    probe,
    run: (request) =>
      probe(request).pipe(
        Effect.flatMap((outcome) =>
          outcome.exitCode === 0
            ? Effect.succeed({
                stdout: outcome.stdout,
                stderr: outcome.stderr
              })
            : Effect.fail(failedError(request, outcome))
        )
      )
  })
})

export const ProcessRunnerLive = Layer.effect(
  ProcessRunner,
  makeProcessRunner
).pipe(Layer.provide(NodeServices.layer))
