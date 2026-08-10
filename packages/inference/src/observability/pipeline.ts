import type { ProgressEvent } from "./progress.js"

export interface ObservedProgressEvent {
  readonly event: ProgressEvent
  readonly invocationId?: string
  readonly cursor?: string
  readonly hostname?: string
  readonly journalTimestamp?: string
}

export interface UnitStatus {
  readonly unit: string
  readonly observedAt: string
  readonly loadState: string
  readonly activeState: string
  readonly subState: string
  readonly result: string
  readonly invocationId?: string
  readonly statusText?: string
}

export type PipelineStepState =
  | "running"
  | "completed"
  | "failed"
  | "warning"

export interface PipelineStep {
  readonly id: string
  readonly lane: string
  readonly scope: ProgressEvent["scope"]
  readonly operation: string
  readonly state: PipelineStepState
  readonly message: string
  readonly updatedAt: string
  readonly instance?: string
  readonly node?: string
  readonly model?: string
  readonly attributes?: Readonly<Record<string, unknown>>
  readonly startedAt?: string
  readonly finishedAt?: string
  readonly completionInferred?: boolean
  readonly progress?: {
    readonly current: number
    readonly total: number
    readonly unit: string
  }
}

export interface PipelineSnapshot {
  readonly instance: string
  readonly recipe: string
  readonly nodes: ReadonlyArray<string>
  readonly controlNode: string
  readonly invocationId?: string
  readonly startedAt?: string
  readonly updatedAt?: string
  readonly unit?: UnitStatus
  readonly steps: ReadonlyArray<PipelineStep>
  readonly recent: ReadonlyArray<ObservedProgressEvent>
}

export type PipelineUpdate =
  | { readonly type: "event"; readonly observed: ObservedProgressEvent }
  | { readonly type: "unit"; readonly status: UnitStatus }
  | { readonly type: "tick" }

const recentLimit = 16

const latestTimestamp = (
  current: string | undefined,
  candidate: string
): string => {
  if (current === undefined) return candidate
  return Date.parse(candidate) >= Date.parse(current) ? candidate : current
}

export const emptyPipelineSnapshot = (metadata: {
  readonly instance: string
  readonly recipe: string
  readonly nodes: ReadonlyArray<string>
  readonly controlNode: string
}): PipelineSnapshot => ({
  ...metadata,
  steps: [],
  recent: []
})

const stepIdentity = (event: ProgressEvent): string =>
  JSON.stringify([
    event.scope,
    event.instance ?? null,
    event.node ?? null,
    event.model ?? null,
    event.operation
  ])

const laneIdentity = (event: ProgressEvent): string =>
  JSON.stringify([
    event.scope,
    event.instance ?? null,
    event.node ?? null,
    event.model ?? null
  ])

const resetForInvocation = (
  snapshot: PipelineSnapshot,
  invocationId: string
): PipelineSnapshot => ({
  instance: snapshot.instance,
  recipe: snapshot.recipe,
  nodes: snapshot.nodes,
  controlNode: snapshot.controlNode,
  invocationId,
  ...(snapshot.unit?.invocationId === invocationId
    ? { unit: snapshot.unit }
    : {}),
  steps: [],
  recent: []
})

const eventPredatesCurrentUnit = (
  snapshot: PipelineSnapshot,
  observed: ObservedProgressEvent
): boolean => {
  const unitInvocation = snapshot.unit?.invocationId
  if (
    unitInvocation === undefined ||
    observed.invocationId === undefined ||
    observed.invocationId === unitInvocation
  ) {
    return false
  }
  return (
    Date.parse(observed.event.timestamp) <
    Date.parse(snapshot.unit?.observedAt ?? observed.event.timestamp)
  )
}

const settlePreviousLaneStep = (
  steps: ReadonlyArray<PipelineStep>,
  lane: string,
  id: string,
  timestamp: string,
  nextState: PipelineStepState
): ReadonlyArray<PipelineStep> =>
  steps.map((step) =>
    step.lane === lane && step.id !== id && step.state === "running"
      ? {
          ...step,
          state:
            nextState === "failed"
              ? ("failed" as const)
              : ("completed" as const),
          updatedAt: timestamp,
          finishedAt: timestamp,
          completionInferred: true
        }
      : step
  )

const applyEvent = (
  snapshot: PipelineSnapshot,
  observed: ObservedProgressEvent
): PipelineSnapshot => {
  if (eventPredatesCurrentUnit(snapshot, observed)) return snapshot

  const event = observed.event
  const invocationChanged =
    observed.invocationId !== undefined &&
    observed.invocationId !== snapshot.invocationId
  const current = invocationChanged
    ? resetForInvocation(snapshot, observed.invocationId!)
    : snapshot
  const id = stepIdentity(event)
  const lane = laneIdentity(event)
  const existing = current.steps.find((step) => step.id === id)
  const state: PipelineStepState =
    event.kind === "progress"
      ? "running"
      : event.state === "started"
        ? "running"
        : event.state
  const steps = settlePreviousLaneStep(
    current.steps,
    lane,
    id,
    event.timestamp,
    state
  )
  const nextStep: PipelineStep = {
    id,
    lane,
    scope: event.scope,
    operation: event.operation,
    state,
    message: event.message,
    updatedAt: event.timestamp,
    ...(event.instance === undefined ? {} : { instance: event.instance }),
    ...(event.node === undefined ? {} : { node: event.node }),
    ...(event.model === undefined ? {} : { model: event.model }),
    ...(event.attributes === undefined ? {} : { attributes: event.attributes }),
    ...(state === "running"
      ? { startedAt: existing?.startedAt ?? event.timestamp }
      : existing?.startedAt === undefined
        ? { finishedAt: event.timestamp }
        : {
            startedAt: existing.startedAt,
            finishedAt: event.timestamp
          }),
    ...(event.kind === "progress"
      ? {
          progress: {
            current: event.current,
            total: event.total,
            unit: event.unit
          }
        }
      : existing?.progress === undefined
        ? {}
        : { progress: existing.progress })
  }
  const index = steps.findIndex((step) => step.id === id)
  const updatedSteps =
    index === -1
      ? [...steps, nextStep]
      : steps.map((step, stepIndex) => (stepIndex === index ? nextStep : step))
  const recent = [...current.recent, observed].slice(-recentLimit)

  return {
    ...current,
    ...(observed.invocationId === undefined
      ? {}
      : { invocationId: observed.invocationId }),
    startedAt: current.startedAt ?? event.timestamp,
    updatedAt: latestTimestamp(current.updatedAt, event.timestamp),
    steps: updatedSteps,
    recent
  }
}

const applyUnitStatus = (
  snapshot: PipelineSnapshot,
  status: UnitStatus
): PipelineSnapshot => {
  if (
    snapshot.updatedAt !== undefined &&
    Date.parse(status.observedAt) < Date.parse(snapshot.updatedAt)
  ) {
    return snapshot
  }
  const invocationChanged =
    status.invocationId !== undefined &&
    status.invocationId !== snapshot.invocationId
  const current = invocationChanged
    ? resetForInvocation(snapshot, status.invocationId!)
    : snapshot
  return {
    ...current,
    ...(status.invocationId === undefined
      ? {}
      : { invocationId: status.invocationId }),
    updatedAt: status.observedAt,
    unit: status
  }
}

export const reducePipelineUpdate = (
  snapshot: PipelineSnapshot,
  update: PipelineUpdate
): PipelineSnapshot => {
  switch (update.type) {
    case "event":
      return applyEvent(snapshot, update.observed)
    case "unit":
      return applyUnitStatus(snapshot, update.status)
    case "tick":
      return snapshot
  }
}

export type PipelineStatus =
  | "unknown"
  | "preparing"
  | "ready"
  | "stopping"
  | "stopped"
  | "failed"

export const pipelineStatus = (snapshot: PipelineSnapshot): PipelineStatus => {
  if (snapshot.steps.some((step) => step.state === "failed")) return "failed"
  const unit = snapshot.unit
  if (unit === undefined) {
    return snapshot.steps.length === 0 ? "unknown" : "preparing"
  }
  if (unit.loadState !== "loaded") return "unknown"
  if (
    unit.activeState === "failed" ||
    (unit.activeState === "inactive" &&
      unit.result !== "success" &&
      unit.result !== "")
  ) {
    return "failed"
  }
  if (unit.activeState === "active") return "ready"
  if (unit.activeState === "activating") return "preparing"
  if (unit.activeState === "deactivating") return "stopping"
  if (unit.activeState === "inactive") return "stopped"
  return snapshot.steps.length === 0 ? "unknown" : "preparing"
}
