import { Context, Effect, Fiber, Layer, Result, Stream } from "effect"
import { ChildProcess, ChildProcessSpawner } from "effect/unstable/process"
import { CommandError } from "../domain/errors.js"
import type { ObservedProgressEvent, UnitStatus } from "../observability/pipeline.js"
import {
  decodeProgressJournalMessage,
  progressJournalPrefix
} from "../observability/progress-journal.js"

export interface JournalEventsRequest {
  readonly unit: string
  readonly follow: boolean
  readonly lines: number
}

export interface JournalReaderService {
  readonly events: (
    request: JournalEventsRequest
  ) => Stream.Stream<ObservedProgressEvent, CommandError>
  readonly status: (unit: string) => Effect.Effect<UnitStatus, CommandError>
}

export class JournalReader extends Context.Service<
  JournalReader,
  JournalReaderService
>()("inference/JournalReader") {}

interface CommandOutput {
  readonly stdout: string
  readonly stderr: string
  readonly exitCode: number
}

const outputLimit = 64 * 1024

const appendOutput = (current: string, chunk: string): string => {
  const output = current + chunk
  return output.length <= outputLimit ? output : output.slice(-outputLimit)
}

const journalError = (
  code: string,
  message: string,
  details?: Readonly<Record<string, unknown>>
): CommandError =>
  new CommandError({
    code,
    message,
    ...(details === undefined ? {} : { details })
  })

export const journalExitSucceeded = (
  exitCode: number,
  follow: boolean,
  stderr: string
): boolean =>
  !follow &&
  (exitCode === 0 || (exitCode === 1 && stderr.trim().length === 0))

const parseFields = (output: string): ReadonlyMap<string, string> => {
  const fields = new Map<string, string>()
  for (const line of output.split("\n")) {
    const separator = line.indexOf("=")
    if (separator <= 0) continue
    fields.set(line.slice(0, separator), line.slice(separator + 1))
  }
  return fields
}

export const decodeUnitStatus = (
  unit: string,
  output: string,
  observedAt: string
): Result.Result<UnitStatus, CommandError> => {
  const fields = parseFields(output)
  const loadState = fields.get("LoadState")
  const activeState = fields.get("ActiveState")
  const subState = fields.get("SubState")
  const result = fields.get("Result")
  if (
    loadState === undefined ||
    activeState === undefined ||
    subState === undefined ||
    result === undefined
  ) {
    return Result.fail(
      journalError(
        "systemd-status-invalid",
        `systemctl returned an incomplete status for '${unit}'`,
        { unit }
      )
    )
  }
  const invocationId = fields.get("InvocationID")
  const statusText = fields.get("StatusText")
  return Result.succeed({
    unit,
    observedAt,
    loadState,
    activeState,
    subState,
    result,
    ...(invocationId === undefined || invocationId.length === 0
      ? {}
      : { invocationId }),
    ...(statusText === undefined || statusText.length === 0 ? {} : { statusText })
  })
}

const stringField = (
  value: Readonly<Record<string, unknown>>,
  key: string
): string | undefined => {
  const field = value[key]
  return typeof field === "string" ? field : undefined
}

export const decodeJournalRecord = (
  line: string
): Result.Result<ObservedProgressEvent | undefined, CommandError> => {
  const source = line.startsWith("\u001e") ? line.slice(1) : line
  let record: unknown
  try {
    record = JSON.parse(source)
  } catch {
    return Result.fail(
      journalError("journal-record-invalid", "journalctl returned invalid JSON")
    )
  }
  if (record === null || typeof record !== "object" || Array.isArray(record)) {
    return Result.fail(
      journalError("journal-record-invalid", "journalctl returned a non-object record")
    )
  }
  const fields = record as Readonly<Record<string, unknown>>
  const message = stringField(fields, "MESSAGE")
  if (message === undefined || !message.startsWith(progressJournalPrefix)) {
    return Result.succeed(undefined)
  }
  const event = decodeProgressJournalMessage(message)
  if (event === undefined) return Result.succeed(undefined)
  const invocationId =
    stringField(fields, "_SYSTEMD_INVOCATION_ID") ??
    stringField(fields, "INVOCATION_ID")
  const cursor = stringField(fields, "__CURSOR")
  const hostname = stringField(fields, "_HOSTNAME")
  const journalTimestamp = stringField(fields, "__REALTIME_TIMESTAMP")
  return Result.succeed({
    event,
    ...(invocationId === undefined ? {} : { invocationId }),
    ...(cursor === undefined ? {} : { cursor }),
    ...(hostname === undefined ? {} : { hostname }),
    ...(journalTimestamp === undefined ? {} : { journalTimestamp })
  })
}

const command = (
  executable: string,
  args: ReadonlyArray<string>
): ChildProcess.StandardCommand =>
  ChildProcess.make(executable, args, {
    detached: false,
    extendEnv: true,
    forceKillAfter: "5 seconds",
    stdin: "ignore",
    stdout: "pipe",
    stderr: "pipe"
  })

const collect = (stream: Stream.Stream<Uint8Array, unknown>) =>
  stream.pipe(
    Stream.decodeText(),
    Stream.runFold(() => "", (output, chunk) => appendOutput(output, chunk))
  )

const makeJournalReader = Effect.gen(function* () {
  const spawner = yield* ChildProcessSpawner.ChildProcessSpawner

  const run = (
    executable: string,
    args: ReadonlyArray<string>
  ): Effect.Effect<CommandOutput, CommandError> =>
    Effect.scoped(
      Effect.gen(function* () {
        const handle = yield* spawner.spawn(command(executable, args))
        const [stdout, stderr, exitCode] = yield* Effect.all(
          [collect(handle.stdout), collect(handle.stderr), handle.exitCode],
          { concurrency: "unbounded" }
        )
        return { stdout, stderr, exitCode: Number(exitCode) }
      }).pipe(
        Effect.mapError(() =>
          journalError(
            "observer-command-start-failed",
            `Unable to run '${executable}'`,
            { command: executable }
          )
        ),
        Effect.flatMap((output) =>
          output.exitCode === 0
            ? Effect.succeed(output)
            : Effect.fail(
                journalError(
                  "observer-command-failed",
                  `'${executable}' exited unsuccessfully`,
                  {
                    command: executable,
                    exitCode: output.exitCode,
                    stderr: output.stderr.trim()
                  }
                )
              )
        )
      )
    )

  const journalStream = (
    unit: string,
    args: ReadonlyArray<string>,
    follow: boolean
  ): Stream.Stream<ObservedProgressEvent, CommandError> =>
    Stream.unwrap(
      Effect.gen(function* () {
        const handle = yield* spawner.spawn(command("journalctl", args))
        const stderr = yield* Effect.forkScoped(collect(handle.stderr))
        const checkExit = Effect.all([handle.exitCode, Fiber.join(stderr)]).pipe(
          Effect.flatMap(([exitCode, errorOutput]) =>
            journalExitSucceeded(Number(exitCode), follow, errorOutput)
              ? Effect.void
              : Effect.fail(
                  journalError(
                    follow ? "journal-follow-ended" : "journal-read-failed",
                    follow
                      ? "journalctl stopped following the inference journal"
                      : "journalctl could not read the inference journal",
                    {
                      unit,
                      exitCode: Number(exitCode),
                      stderr: errorOutput.trim()
                    }
                  )
                )
          ),
          Effect.mapError((error) =>
            error instanceof CommandError
              ? error
              : journalError(
                  "journal-read-failed",
                  "Unable to read the inference journal",
                  { unit }
                )
          )
        )
        return handle.stdout.pipe(
          Stream.decodeText(),
          Stream.splitLines,
          Stream.mapEffect((line) =>
            Effect.fromResult(decodeJournalRecord(line))
          ),
          Stream.filter(
            (observed): observed is ObservedProgressEvent => observed !== undefined
          ),
          Stream.concat(Stream.fromEffect(checkExit).pipe(Stream.drain)),
          Stream.mapError((error) =>
            error instanceof CommandError
              ? error
              : journalError(
                  "journal-read-failed",
                  "Unable to read the inference journal",
                  { unit }
                )
          )
        )
      }).pipe(
        Effect.mapError(() =>
          journalError("journal-read-failed", "Unable to start journalctl", {
            unit
          })
        )
      )
    )

  const eventTime = (observed: ObservedProgressEvent): number => {
    const journalTime = Number(observed.journalTimestamp)
    return Number.isFinite(journalTime)
      ? journalTime
      : Date.parse(observed.event.timestamp)
  }

  const events = (
    request: JournalEventsRequest
  ): Stream.Stream<ObservedProgressEvent, CommandError> => {
    const baseArguments = [
      `--unit=${request.unit}`,
      "--no-pager",
      "--output=json-seq",
      "--output-fields=__CURSOR,__REALTIME_TIMESTAMP,_HOSTNAME,_SYSTEMD_INVOCATION_ID,INVOCATION_ID,MESSAGE",
      `--grep=^${progressJournalPrefix}`
    ]
    const replay = journalStream(
      request.unit,
      [...baseArguments, `--lines=${request.lines}`],
      false
    )
    return Stream.unwrap(
      replay.pipe(
        Stream.runCollect,
        Effect.map((events) => {
          const ordered = [...events].sort(
            (left, right) => eventTime(left) - eventTime(right)
          )
          if (!request.follow) return Stream.fromIterable(ordered)
          const cursor = ordered.at(-1)?.cursor
          const follow = journalStream(
            request.unit,
            [
              ...baseArguments,
              ...(cursor === undefined
                ? ["--lines=0"]
                : [`--after-cursor=${cursor}`]),
              "--follow"
            ],
            true
          )
          return Stream.concat(Stream.fromIterable(ordered), follow)
        })
      )
    )
  }

  return JournalReader.of({
    events,
    status: (unit) =>
      Effect.gen(function* () {
        const observedAt = new Date().toISOString()
        const output = yield* run("systemctl", [
          "show",
          unit,
          "--no-pager",
          "--property=LoadState",
          "--property=ActiveState",
          "--property=SubState",
          "--property=Result",
          "--property=InvocationID",
          "--property=StatusText"
        ])
        return yield* Effect.fromResult(
          decodeUnitStatus(unit, output.stdout, observedAt)
        )
      })
  })
})

export const JournalReaderLive = Layer.effect(JournalReader, makeJournalReader)
