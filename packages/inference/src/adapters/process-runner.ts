import { spawn, type ChildProcess } from "node:child_process"
import { Context, Effect, Layer } from "effect"
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
  readonly probe: (
    request: ProcessRequest
  ) => Effect.Effect<ProcessOutcome, CommandError>
  readonly run: (
    request: ProcessRequest
  ) => Effect.Effect<ProcessResult, CommandError>
}

export class ProcessRunner extends Context.Tag("inference/ProcessRunner")<
  ProcessRunner,
  ProcessRunnerService
>() {}

const outputLimit = 64 * 1024

const appendOutput = (current: string, chunk: Uint8Array): string => {
  const next = current + Buffer.from(chunk).toString("utf8")
  return next.length <= outputLimit ? next : next.slice(-outputLimit)
}

export const terminateProcess = (
  child: ChildProcess
): Effect.Effect<void> =>
  Effect.async((resume) => {
    if (child.exitCode !== null || child.signalCode !== null) {
      resume(Effect.void)
      return
    }

    const force = setTimeout(() => child.kill("SIGKILL"), 5_000)
    child.once("close", () => {
      clearTimeout(force)
      resume(Effect.void)
    })
    child.kill("SIGTERM")

    return Effect.sync(() => {
      clearTimeout(force)
      child.kill("SIGKILL")
    })
  })

export const runForeground = (
  request: ProcessRequest
): Effect.Effect<void, CommandError> =>
  Effect.async((resume) => {
    let settled = false
    const child = spawn(request.command, [...request.args], {
      env: {
        ...process.env,
        ...request.environment
      },
      stdio: "inherit"
    })
    child.once("error", () => {
      if (settled) return
      settled = true
      resume(
        Effect.fail(
          new CommandError({
            code: "external-command-start-failed",
            message: `Unable to start '${request.command}'`,
            details: { command: request.command }
          })
        )
      )
    })
    child.once("close", (exitCode, signal) => {
      if (settled) return
      settled = true
      resume(
        exitCode === 0
          ? Effect.void
          : Effect.fail(
              new CommandError({
                code: "external-command-failed",
                message: `'${request.command}' exited unsuccessfully`,
                details: { command: request.command, exitCode, signal }
              })
            )
      )
    })
    return settled ? undefined : terminateProcess(child)
  })

const probe = (
  request: ProcessRequest
): Effect.Effect<ProcessOutcome, CommandError> =>
  Effect.async((resume) => {
    let stdout = ""
    let stderr = ""
    let settled = false
    const child = spawn(request.command, [...request.args], {
      env: {
        ...process.env,
        ...request.environment
      },
      stdio: [request.input === undefined ? "ignore" : "pipe", "pipe", "pipe"]
    })

    if (request.input !== undefined) {
      child.stdin?.on("error", () => {})
      child.stdin?.end(request.input)
    }

    child.stdout?.on("data", (chunk: Uint8Array) => {
      stdout = appendOutput(stdout, chunk)
    })
    child.stderr?.on("data", (chunk: Uint8Array) => {
      stderr = appendOutput(stderr, chunk)
    })
    child.once("error", () => {
      if (settled) return
      settled = true
      resume(
        Effect.fail(
          new CommandError({
            code: "external-command-start-failed",
            message: `Unable to start '${request.command}'`,
            details: { command: request.command }
          })
        )
      )
    })
    child.once("close", (code, signal) => {
      if (settled) return
      settled = true
      resume(Effect.succeed({ stdout, stderr, exitCode: code, signal }))
    })

    return settled ? undefined : terminateProcess(child)
  })

export const ProcessRunnerLive = Layer.succeed(ProcessRunner, {
  probe,
  run: (request) =>
    probe(request).pipe(
      Effect.flatMap((outcome) =>
        outcome.exitCode === 0
          ? Effect.succeed({
              stdout: outcome.stdout,
              stderr: outcome.stderr
            })
          : Effect.fail(
              new CommandError({
                code: "external-command-failed",
                message: `'${request.command}' exited unsuccessfully`,
                details: {
                  command: request.command,
                  exitCode: outcome.exitCode,
                  signal: outcome.signal,
                  stderr: outcome.stderr.trim()
                }
              })
            )
      )
    )
})
