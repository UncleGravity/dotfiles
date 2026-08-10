import { Effect, Option, Stream } from "effect"
import { CommandError } from "../domain/errors.js"
import {
  pipelineStatus,
  type PipelineSnapshot,
  type PipelineStatus,
  type PipelineStep
} from "../observability/pipeline.js"

interface RenderOptions {
  readonly width: number
  readonly height: number
  readonly now: number
  readonly color: boolean
  readonly footer: boolean
}

const ansi = {
  reset: "\u001b[0m",
  bold: "\u001b[1m",
  dim: "\u001b[2m",
  red: "\u001b[31m",
  green: "\u001b[32m",
  yellow: "\u001b[33m",
  cyan: "\u001b[36m"
} as const

const styled = (enabled: boolean, code: string, value: string): string =>
  enabled ? `${code}${value}${ansi.reset}` : value

const plainText = (value: string): string =>
  value.replace(/\u001b\[[0-9;]*m/g, "")

const truncate = (value: string, width: number): string => {
  if (width <= 0) return ""
  if (value.length <= width) return value
  return width <= 3 ? value.slice(0, width) : `${value.slice(0, width - 3)}...`
}

const fitLine = (value: string, width: number): string =>
  plainText(value).length <= Math.max(20, width)
    ? value
    : truncate(plainText(value), Math.max(20, width))

const pad = (value: string, width: number): string => {
  const visible = plainText(value)
  return visible.length > width
    ? truncate(visible, width)
    : `${value}${" ".repeat(width - visible.length)}`
}

const parseTime = (timestamp: string | undefined): number | undefined => {
  if (timestamp === undefined) return undefined
  const parsed = Date.parse(timestamp)
  return Number.isFinite(parsed) ? parsed : undefined
}

const duration = (start: string | undefined, end: number): string => {
  const started = parseTime(start)
  if (started === undefined) return "--:--"
  const seconds = Math.max(0, Math.floor((end - started) / 1000))
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const remaining = seconds % 60
  return hours > 0
    ? `${hours}:${minutes.toString().padStart(2, "0")}:${remaining
        .toString()
        .padStart(2, "0")}`
    : `${minutes.toString().padStart(2, "0")}:${remaining
        .toString()
        .padStart(2, "0")}`
}

const statusColor = (status: PipelineStatus): string => {
  switch (status) {
    case "ready":
      return ansi.green
    case "failed":
      return ansi.red
    case "preparing":
    case "stopping":
      return ansi.yellow
    case "unknown":
    case "stopped":
      return ansi.dim
  }
}

const stepMarker = (step: PipelineStep | undefined): string => {
  if (step === undefined) return "[?]"
  switch (step.state) {
    case "running":
      return "[>]"
    case "completed":
      return step.completionInferred === true ? "[-]" : "[ok]"
    case "warning":
      return "[!]"
    case "failed":
      return "[x]"
  }
}

const markerColor = (step: PipelineStep | undefined): string => {
  if (step === undefined) return ansi.dim
  switch (step.state) {
    case "running":
      return ansi.yellow
    case "completed":
      return step.completionInferred === true ? ansi.dim : ansi.green
    case "warning":
      return ansi.yellow
    case "failed":
      return ansi.red
  }
}

const renderMarker = (step: PipelineStep | undefined, color: boolean): string =>
  styled(color, markerColor(step), stepMarker(step))

const modelName = (step: PipelineStep): string | undefined => {
  const value = step.attributes?.modelName
  return typeof value === "string" ? value : undefined
}

const stepLabel = (step: PipelineStep): string => {
  const model = modelName(step)
  return model === undefined ? step.operation : `${step.operation}:${model}`
}

const stepEnd = (step: PipelineStep, now: number): number =>
  parseTime(step.finishedAt) ?? now

const renderControllerSteps = (
  snapshot: PipelineSnapshot,
  options: RenderOptions,
  limit: number
): ReadonlyArray<string> => {
  const steps = snapshot.steps
    .filter((step) => step.node === undefined)
    .slice(-limit)
  if (steps.length === 0) return [styled(options.color, ansi.dim, "No events yet")]
  const labelWidth = Math.min(
    28,
    Math.max(16, ...steps.map((step) => stepLabel(step).length))
  )
  return steps.map((step) => {
    const detail =
      step.progress === undefined
        ? step.message
        : `${step.progress.current}/${step.progress.total} ${step.progress.unit}  ${step.message}`
    const prefix = `${renderMarker(step, options.color)} ${pad(
      stepLabel(step),
      labelWidth
    )} ${duration(step.startedAt, stepEnd(step, options.now)).padStart(8)}  `
    return fitLine(`${prefix}${detail}`, options.width)
  })
}

const nodeStep = (
  snapshot: PipelineSnapshot,
  node: string,
  operation: string
): PipelineStep | undefined =>
  [...snapshot.steps]
    .reverse()
    .find((step) => step.node === node && step.operation === operation)

const stringAttribute = (
  step: PipelineStep | undefined,
  name: string
): string | undefined => {
  const value = step?.attributes?.[name]
  return typeof value === "string" ? value : undefined
}

const readinessState = (step: PipelineStep | undefined): string => {
  const activeState = stringAttribute(step, "activeState")
  const subState = stringAttribute(step, "subState")
  return activeState === undefined || subState === undefined
    ? "unknown"
    : `${activeState}/${subState}`
}

const launchLabel = (
  step: PipelineStep | undefined,
  color: boolean
): string => {
  const detail =
    step?.state === "completed"
      ? "accepted"
      : step?.state === "running"
        ? "requesting"
        : step?.state === "failed"
          ? "failed"
          : ""
  return `${renderMarker(step, color)}${detail === "" ? "" : ` ${detail}`}`
}

const readinessDetail = (
  step: PipelineStep | undefined,
  options: RenderOptions
): string => {
  if (step === undefined) return "No readiness event"
  const elapsed = duration(step.startedAt, stepEnd(step, options.now))
  switch (step.state) {
    case "running":
      return `${step.message} (${elapsed})`
    case "completed":
      return step.startedAt === undefined ? "Ready" : `Ready in ${elapsed}`
    case "failed":
    case "warning":
      return step.message
  }
}

const unitStateLabel = (
  readiness: PipelineStep | undefined,
  stop: PipelineStep | undefined,
  color: boolean
): string => {
  if (stop === undefined) {
    return `${renderMarker(readiness, color)} ${readinessState(readiness)}`
  }
  switch (stop.state) {
    case "running":
      return `${renderMarker(stop, color)} stopping`
    case "completed":
      return styled(color, ansi.dim, "[--] stopped")
    case "warning":
    case "failed":
      return `${renderMarker(stop, color)} stop-failed`
  }
}

const unitStateDetail = (
  readiness: PipelineStep | undefined,
  stop: PipelineStep | undefined,
  options: RenderOptions
): string => {
  if (stop === undefined) return readinessDetail(readiness, options)
  switch (stop.state) {
    case "running":
      return `${stop.message} (${duration(stop.startedAt, options.now)})`
    case "completed":
      return "Stopped by controller"
    case "warning":
    case "failed":
      return stop.message
  }
}

const renderNodes = (
  snapshot: PipelineSnapshot,
  options: RenderOptions
): ReadonlyArray<string> => {
  const includePrepare = options.width >= 72
  const narrow = options.width < 52
  const maxNodeWidth = includePrepare ? 18 : narrow ? 10 : 13
  const nodeWidth = Math.min(
    maxNodeWidth,
    Math.max(10, ...snapshot.nodes.map((node) => node.length))
  )
  const includeDetail = options.width >= 88
  const launchWidth = narrow ? 4 : 13
  const header = [
    pad("NODE", nodeWidth),
    ...(includePrepare ? [pad("PREPARE", 11)] : []),
    pad(narrow ? "RUN" : "LAUNCH", launchWidth),
    pad("UNIT STATE", 22)
  ].join("  ")
  const rows = snapshot.nodes.map((node) => {
    const prepare = nodeStep(snapshot, node, "prepare-node")
    const start = nodeStep(snapshot, node, "start-node")
    const readiness = nodeStep(snapshot, node, "node-readiness")
    const stop = nodeStep(snapshot, node, "stop-node")
    const local = node === snapshot.controlNode && prepare === undefined
    const prepareLabel = local
      ? styled(options.color, ansi.dim, "[--] local")
      : `${renderMarker(prepare, options.color)} ${
          prepare?.state === "running" ? "running" : ""
        }`
    const base = [
      pad(node, nodeWidth),
      ...(includePrepare ? [pad(prepareLabel, 11)] : []),
      pad(
        narrow
          ? renderMarker(start, options.color)
          : launchLabel(start, options.color),
        launchWidth
      ),
      pad(unitStateLabel(readiness, stop, options.color), 22)
    ].join("  ")
    return fitLine(
      includeDetail
        ? `${base}  ${unitStateDetail(readiness, stop, options)}`
        : base,
      options.width
    )
  })
  return [
    styled(
      options.color,
      ansi.bold,
      `${header}${includeDetail ? "  DETAIL" : ""}`
    ),
    ...rows
  ]
}

const renderRecent = (
  snapshot: PipelineSnapshot,
  options: RenderOptions,
  limit: number
): ReadonlyArray<string> => {
  const events = snapshot.recent.slice(-limit)
  if (events.length === 0) return [styled(options.color, ansi.dim, "No events yet")]
  return events.map(({ event }) => {
    const parsed = parseTime(event.timestamp)
    const timestamp =
      parsed === undefined
        ? "--:--:--"
        : new Date(parsed).toLocaleTimeString("en-US", {
            hour12: false,
            hour: "2-digit",
            minute: "2-digit",
            second: "2-digit"
          })
    const lane = event.node ?? event.scope
    const marker =
      event.kind === "progress"
        ? "[>]"
        : event.state === "completed"
          ? "[ok]"
          : event.state === "failed"
            ? "[x]"
            : event.state === "warning"
              ? "[!]"
              : "[>]"
    return fitLine(
      `${timestamp}  ${pad(lane, 12)}  ${marker} ${event.message}`,
      options.width
    )
  })
}

export const renderPipeline = (
  snapshot: PipelineSnapshot,
  options: RenderOptions
): string => {
  const width = Math.max(40, options.width)
  const renderOptions = { ...options, width }
  const status = pipelineStatus(snapshot)
  const invocation = snapshot.invocationId?.slice(0, 12) ?? "none"
  const terminal = status === "failed" || status === "stopped"
  const elapsed = duration(
    snapshot.startedAt,
    terminal
      ? (parseTime(snapshot.unit?.observedAt) ?? options.now)
      : options.now
  )
  const unitState =
    snapshot.unit === undefined
      ? "unavailable"
      : `${snapshot.unit.activeState}/${snapshot.unit.subState}${
          snapshot.unit.result === "success"
            ? ""
            : ` result=${snapshot.unit.result}`
        }`
  const title = `${styled(options.color, ansi.bold, `INFER ${snapshot.instance}`)}  ${styled(
    options.color,
    statusColor(status),
    status.toUpperCase()
  )}`
  const metadata = `recipe ${snapshot.recipe}  unit ${unitState}  elapsed ${elapsed}  invocation ${invocation}`
  const statusText = snapshot.unit?.statusText
  const fixedRows =
    snapshot.nodes.length +
    9 +
    (statusText === undefined ? 0 : 1) +
    (options.footer ? 2 : 0)
  const dynamicRows = Math.max(2, options.height - fixedRows)
  const recentRows = Math.min(6, Math.max(1, Math.floor(dynamicRows / 3)))
  const controllerRows = Math.min(10, Math.max(1, dynamicRows - recentRows))

  return [
    fitLine(title, width),
    fitLine(metadata, width),
    ...(statusText === undefined
      ? []
      : [fitLine(`status ${statusText}`, width)]),
    "",
    styled(options.color, ansi.cyan, "CONTROLLER"),
    ...renderControllerSteps(snapshot, renderOptions, controllerRows),
    "",
    styled(options.color, ansi.cyan, "NODES"),
    ...renderNodes(snapshot, renderOptions),
    "",
    styled(options.color, ansi.cyan, "RECENT"),
    ...renderRecent(snapshot, renderOptions, recentRows),
    ...(options.footer
      ? ["", styled(options.color, ansi.dim, "Ctrl-C to exit")]
      : [])
  ].join("\n")
}

const write = (value: string): Effect.Effect<void> =>
  Effect.sync(() => {
    process.stdout.write(value)
  })

const terminalRequired = new CommandError({
  code: "terminal-required",
  message: "Live watch requires a terminal; use --once for a single snapshot"
})

export const runWatchView = <R>(
  snapshots: Stream.Stream<PipelineSnapshot, CommandError, R>,
  follow: boolean
): Effect.Effect<void, CommandError, R> => {
  if (!follow) {
    return snapshots.pipe(
      Stream.runLast,
      Effect.flatMap((last) =>
        Option.match(last, {
          onNone: () => Effect.void,
          onSome: (snapshot) =>
            write(
              `${renderPipeline(snapshot, {
                width: process.stdout.columns ?? 100,
                height: Number.MAX_SAFE_INTEGER,
                now: Date.now(),
                color: false,
                footer: false
              })}\n`
            )
        })
      )
    )
  }
  if (process.stdout.isTTY !== true) return Effect.fail(terminalRequired)

  const enter = "\u001b[?1049h\u001b[?25l"
  const leave = "\u001b[0m\u001b[?25h\u001b[?1049l"
  return Effect.scoped(
    Effect.acquireRelease(write(enter), () => write(leave)).pipe(
      Effect.andThen(
        snapshots.pipe(
          Stream.runForEach((snapshot) =>
            write(
              `\u001b[H\u001b[2J${renderPipeline(snapshot, {
                width: process.stdout.columns ?? 100,
                height: process.stdout.rows ?? 24,
                now: Date.now(),
                color: process.env.NO_COLOR === undefined,
                footer: true
              })}`
            )
          )
        )
      )
    )
  )
}
