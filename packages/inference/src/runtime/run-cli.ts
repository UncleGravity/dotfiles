import { NodeContext, NodeRuntime } from "@effect/platform-node"
import { Console, Effect } from "effect"
import { CommandError, commandErrorJson } from "../domain/errors.js"

export const runCli = <E>(
  program: Effect.Effect<void, E, NodeContext.NodeContext>
): void => {
  const jsonRequested = process.argv.includes("--json")

  const handled = Console.consoleWith((console) => {
    const quietParserConsole: Console.Console = {
      ...console,
      error: () => Effect.void
    }

    const run = program.pipe(
      Effect.catchAll((error) =>
        Effect.sync(() => {
          if (jsonRequested) {
            const kind =
              typeof error === "object" && error !== null && "_tag" in error
                ? String(error._tag)
                : "Unknown"
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

    return jsonRequested
      ? run.pipe(Console.withConsole(quietParserConsole))
      : run
  })

  handled.pipe(Effect.provide(NodeContext.layer), NodeRuntime.runMain)
}
