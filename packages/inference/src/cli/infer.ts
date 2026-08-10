import { Effect } from "effect"
import { Argument, Command, Flag } from "effect/unstable/cli"
import { loadContract } from "../adapters/contract-files.js"
import {
  Catalog,
  InstanceCatalog,
  Inventory,
  type RunPlan
} from "../domain/contracts.js"
import {
  listInstances,
  listRecipes,
  planInstance
} from "../domain/planner.js"
import { handleCommand, printOutput } from "./output.js"

const catalogOption = Flag.string("catalog").pipe(
  Flag.withDefault("/etc/infer/catalog.json"),
  Flag.withDescription("Path to the evaluated recipe catalog")
)

const inventoryOption = Flag.string("inventory").pipe(
  Flag.withDefault("/etc/infer/inventory.json"),
  Flag.withDescription("Path to the evaluated deployment inventory")
)

const instancesOption = Flag.string("instances").pipe(
  Flag.withDefault("/etc/infer/instances.json"),
  Flag.withDescription("Path to the evaluated instance catalog")
)

const jsonOption = Flag.boolean("json").pipe(
  Flag.withDescription("Write one versioned JSON value")
)

const renderRecipeList = (value: ReturnType<typeof listRecipes>): string => {
  if (value.recipes.length === 0) return "No recipes"
  const rows = value.recipes.map(
    (recipe) =>
      `${recipe.name}\t${recipe.nodeCounts.join(",")}\t${recipe.startOrder}\t${recipe.platform}\t${recipe.models.join(",")}`
  )
  return ["NAME\tNODES\tSTART ORDER\tPLATFORM\tMODELS", ...rows].join("\n")
}

const recipesList = Command.make(
  "list",
  { catalog: catalogOption, json: jsonOption },
  ({ catalog, json }) =>
    handleCommand(
      json,
      Effect.gen(function* () {
        const loaded = yield* loadContract(catalog, "Catalog", Catalog)
        const value = listRecipes(loaded.value)
        yield* printOutput(json, value, renderRecipeList(value))
      })
    )
).pipe(Command.withDescription("List recipes in this deployment"))

const recipes = Command.make("recipes").pipe(
  Command.withDescription("Inspect inference recipes"),
  Command.withSubcommands([recipesList])
)

const renderInstanceList = (value: InstanceCatalog): string => {
  if (value.instances.length === 0) return "No instances"
  const rows = value.instances.map(
    (instance) =>
      `${instance.name}\t${instance.recipe}\t${instance.nodes.join(",")}\t${instance.nodes[0]}\t${instance.autoStart ? "yes" : "no"}`
  )
  return ["NAME\tRECIPE\tNODES\tHEAD\tAUTOSTART", ...rows].join("\n")
}

const instancesList = Command.make(
  "list",
  { instances: instancesOption, json: jsonOption },
  ({ instances, json }) =>
    handleCommand(
      json,
      Effect.gen(function* () {
        const loaded = yield* loadContract(
          instances,
          "InstanceCatalog",
          InstanceCatalog
        )
        const value = listInstances(loaded.value)
        yield* printOutput(json, value, renderInstanceList(value))
      })
    )
).pipe(Command.withDescription("List declared inference instances"))

const instances = Command.make("instances").pipe(
  Command.withDescription("Inspect Nix-declared inference instances"),
  Command.withSubcommands([instancesList])
)

const instanceArgument = Argument.string("instance").pipe(
  Argument.withDescription("Declared inference instance name")
)

const renderPlan = (plan: RunPlan): string =>
  [
    `Recipe: ${plan.recipe.name}`,
    `Start order: ${plan.startOrder}`,
    `Nodes: ${plan.nodes.join(", ")}`,
    `Head: ${plan.head}`,
    `Models: ${plan.models.map((model) => model.name).join(", ")}`,
    `Build: ${plan.image.buildHash}`,
    `Health: ${plan.endpoint.healthUrl}`
  ].join("\n")

const plan = Command.make(
  "plan",
  {
    instance: instanceArgument,
    catalog: catalogOption,
    inventory: inventoryOption,
    instances: instancesOption,
    json: jsonOption
  },
  ({ instance, catalog, inventory, instances, json }) =>
    handleCommand(
      json,
      Effect.gen(function* () {
        const [loadedCatalog, loadedInventory, loadedInstances] =
          yield* Effect.all([
            loadContract(catalog, "Catalog", Catalog),
            loadContract(inventory, "Inventory", Inventory),
            loadContract(instances, "InstanceCatalog", InstanceCatalog)
          ])
        const value = yield* Effect.fromResult(
          planInstance(
            loadedCatalog.value,
            loadedInventory.value,
            loadedInventory.raw,
            loadedInstances.value,
            instance
          )
        )
        yield* printOutput(json, value, renderPlan(value))
      })
    )
).pipe(Command.withDescription("Show a declared instance's deterministic plan"))

export const inferCommand = Command.make("infer").pipe(
  Command.withDescription("Inspect declarative inference services"),
  Command.withSubcommands([recipes, instances, plan])
)
