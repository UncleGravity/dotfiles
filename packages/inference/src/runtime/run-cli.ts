import * as NodeRuntime from "@effect/platform-node/NodeRuntime"
import * as NodeServices from "@effect/platform-node/NodeServices"
import { Console, Effect } from "effect"
import { CommandError, commandErrorJson } from "../domain/errors.js"

export const runCli = <E>(
  program: Effect.Effect<void, E, NodeServices.NodeServices>
): void => {
  const jsonRequested = process.argv.includes("--json")

  const handled = Effect.gen(function* () {
    const console = yield* Console.Console
    const quietParserConsole: Console.Console = {
      ...console,
      error: () => {},
      log: () => {}
    }

    const run = program.pipe(
      Effect.catch((error) =>
        Effect.sync(() => {
          if (jsonRequested) {
            let kind =
              typeof error === "object" && error !== null && "_tag" in error
                ? String(error._tag)
                : "Unknown"
            if (
              kind === "ShowHelp" &&
              typeof error === "object" &&
              error !== null &&
              "errors" in error &&
              Array.isArray(error.errors) &&
              error.errors.length > 0
            ) {
              const cause = error.errors[0]
              kind =
                typeof cause === "object" && cause !== null && "_tag" in cause
                  ? String(cause._tag)
                  : kind
            }
            if (kind === "MissingArgument") kind = "MissingValue"
            const commandError = new CommandError({
              code: "invalid-command",
              message: "Invalid command line",
              details: { kind }
            })
            process.stderr.write(
              `${JSON.stringify(commandErrorJson(commandError))}\n`
            )
          }
          process.exitCode = 2
        })
      )
    )

    return yield* (jsonRequested
      ? run.pipe(Effect.provideService(Console.Console, quietParserConsole))
      : run)
  })

  handled.pipe(Effect.provide(NodeServices.layer), NodeRuntime.runMain)
}
