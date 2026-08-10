import { Context, Duration, Effect, Layer, Option } from "effect"

export interface HealthProbeService {
  readonly reachable: (url: string) => Effect.Effect<boolean>
}

export class HealthProbe extends Context.Service<
  HealthProbe,
  HealthProbeService
>()("inference/HealthProbe") {}

export const makeHealthProbe = (
  request: typeof globalThis.fetch = globalThis.fetch,
  timeout: Duration.Input = "2 seconds"
): HealthProbeService => ({
  reachable: (url) =>
    Effect.tryPromise({
      try: (signal) => request(url, { signal }),
      catch: () => false
    }).pipe(
      Effect.match({
        onFailure: () => false,
        onSuccess: (response) => response.ok
      }),
      Effect.timeoutOption(timeout),
      Effect.map(Option.getOrElse(() => false))
    )
})

export const HealthProbeLive = Layer.succeed(HealthProbe, makeHealthProbe())
