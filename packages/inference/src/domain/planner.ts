import { createHash } from "node:crypto"
import * as path from "node:path"
import { Result } from "effect"
import type {
  Catalog,
  InstanceCatalog,
  InstanceDeclaration,
  Inventory,
  InventoryNode,
  NodePlan,
  PlannedModel,
  Recipe,
  RunPlan
} from "./contracts.js"
import { CommandError } from "./errors.js"
import { artifactIdentity } from "./model-artifact.js"

export interface PlanRequest {
  readonly recipe: string
  readonly nodes?: ReadonlyArray<string>
}

const fail = (
  code: string,
  message: string,
  details?: Readonly<Record<string, unknown>>
): Result.Result<never, CommandError> =>
  Result.fail(
    new CommandError({
      code,
      message,
      ...(details === undefined ? {} : { details })
    })
  )

export const findInstance = (
  instances: InstanceCatalog,
  name: string
): Result.Result<InstanceDeclaration, CommandError> => {
  const instance = instances.instances.find(
    (candidate) => candidate.name === name
  )
  return instance === undefined
    ? fail(
        "instance-not-found",
        `Instance '${name}' is not declared in this deployment`,
        { instance: name }
      )
    : Result.succeed(instance)
}

const hash = (value: string): string =>
  createHash("sha256").update(value, "utf8").digest("hex")

export const findRecipe = (
  catalog: Catalog,
  name: string
): Result.Result<Recipe, CommandError> => {
  const recipe = catalog.recipes.find((candidate) => candidate.name === name)
  return recipe === undefined
    ? fail("recipe-not-found", `Recipe '${name}' is not in this catalog`, {
        recipe: name
      })
    : Result.succeed(recipe)
}

const validateInventory = (
  inventory: Inventory
): Result.Result<ReadonlyMap<string, InventoryNode>, CommandError> => {
  const names = inventory.nodes.map((node) => node.name)
  const expectedOrder = [...names].sort((left, right) =>
    left < right ? -1 : left > right ? 1 : 0
  )
  if (new Set(names).size !== names.length) {
    return fail("invalid-inventory", "Inventory contains duplicate node names")
  }
  if (names.some((name, index) => name !== expectedOrder[index])) {
    return fail(
      "invalid-inventory",
      "Inventory nodes are not in canonical name order"
    )
  }

  const nodes = new Map(inventory.nodes.map((node) => [node.name, node]))
  if (!nodes.has(inventory.localNode)) {
    return fail("invalid-inventory", "Inventory localNode is not declared", {
      localNode: inventory.localNode
    })
  }
  if (!nodes.has(inventory.controlNode)) {
    return fail("invalid-inventory", "Inventory controlNode is not declared", {
      controlNode: inventory.controlNode
    })
  }
  return Result.succeed(nodes)
}

const selectNodes = (
  recipe: Recipe,
  inventory: Inventory,
  nodeMap: ReadonlyMap<string, InventoryNode>,
  requested: ReadonlyArray<string> | undefined
): Result.Result<ReadonlyArray<InventoryNode>, CommandError> => {
  if (requested !== undefined && new Set(requested).size !== requested.length) {
    return fail("duplicate-node", "The explicit node list contains duplicates", {
      nodes: requested
    })
  }

  if (requested === undefined && inventory.nodes.length !== 1) {
    return fail(
      "node-selection-required",
      "Multi-node deployments require an explicit ordered node selection"
    )
  }

  const selectedNames =
    requested === undefined ? [inventory.localNode] : [...requested]

  if (requested !== undefined) {
    const unknown = requested.filter((name) => !nodeMap.has(name))
    if (unknown.length > 0) {
      return fail("unknown-node", "The node selection is not in this deployment", {
        nodes: unknown
      })
    }
  }

  if (selectedNames.length === 0) {
    return fail("empty-node-selection", "At least one node must be selected")
  }

  if (!recipe.topology.nodeCounts.includes(selectedNames.length)) {
    return fail(
      "unsupported-node-count",
      `Recipe '${recipe.name}' does not support ${selectedNames.length} node(s)`,
      {
        nodeCounts: recipe.topology.nodeCounts,
        selectedNodeCount: selectedNames.length
      }
    )
  }

  const selected = selectedNames.map((name) => nodeMap.get(name)!)
  const incompatible = selected
    .filter((node) => node.platform !== recipe.image.platform)
    .map((node) => node.name)
  if (incompatible.length > 0) {
    return fail(
      "platform-mismatch",
      `Recipe '${recipe.name}' does not match every selected node platform`,
      { nodes: incompatible, requiredPlatform: recipe.image.platform }
    )
  }

  if (selected.length > 1) {
    const withoutFabric = selected
      .filter((node) => node.fabric.fabric0 === undefined)
      .map((node) => node.name)
    if (withoutFabric.length > 0) {
      return fail(
        "missing-fabric-address",
        "Clustered nodes require fabric0 addresses",
        { nodes: withoutFabric }
      )
    }
  }

  return Result.succeed(selected)
}

const planModels = (
  recipe: Recipe,
  inventory: Inventory
): ReadonlyArray<PlannedModel> =>
  recipe.models.map((model) => {
    const artifact = artifactIdentity(
      model.repo,
      model.revision,
      model.selection
    )
    const filesPath = path.posix.join(
      inventory.modelStore.localRoot,
      artifact.relativePath,
      "files"
    )
    return {
      name: model.name,
      artifact,
      mount: {
        sourcePath: filesPath,
        targetPath: path.posix.join("/models", model.name),
        readOnly: true
      }
    }
  })

export const planRun = (
  catalog: Catalog,
  inventory: Inventory,
  inventoryJson: string,
  request: PlanRequest
): Result.Result<RunPlan, CommandError> =>
  Result.gen(function* () {
    const recipe = yield* findRecipe(catalog, request.recipe)
    const nodeMap = yield* validateInventory(inventory)
    const selected = yield* selectNodes(
      recipe,
      inventory,
      nodeMap,
      request.nodes
    )
    const head = selected[0]!
    const models = planModels(recipe, inventory)
    const headAddress =
      selected.length > 1
        ? head.fabric.fabric0!
        : head.managementAddress
    const plannedNodes = selected.map((node, rank): NodePlan => {
      const role: NodePlan["role"] =
        selected.length === 1
          ? "single"
          : rank === 0
            ? "head"
            : "worker"
      return {
        node: node.name,
        role,
        rank,
        container: {
          devices: recipe.container.devices,
          network: "host",
          extraOptions: recipe.container.extraOptions,
          environment: {
            ...recipe.container.environment,
            HF_HUB_OFFLINE: "1",
            INFER_HEAD_ADDRESS: headAddress,
            INFER_HEAD_NODE: head.name,
            INFER_NODE: node.name,
            INFER_NODE_ADDRESS:
              selected.length > 1
                ? node.fabric.fabric0!
                : node.managementAddress,
            INFER_PORT: String(recipe.endpoint.port),
            INFER_RANK: String(rank),
            INFER_ROLE: role,
            INFER_WORLD_SIZE: String(selected.length)
          },
          args: recipe.container.args,
          mounts: [
            ...models.map((model) => model.mount),
            ...recipe.container.mounts
          ]
        }
      }
    })

    return {
      schemaVersion: 1,
      recipe: {
        name: recipe.name,
        hash: recipe.recipeHash
      },
      inventoryHash: hash(inventoryJson),
      startOrder: recipe.topology.startOrder,
      nodes: selected.map((node) => node.name) as [string, ...Array<string>],
      head: head.name,
      models: models as [PlannedModel, ...Array<PlannedModel>],
      image: {
        platform: recipe.image.platform,
        buildHash: recipe.image.buildHash
      },
      nodePlans: [plannedNodes[0]!, ...plannedNodes.slice(1)],
      endpoint: {
        node: head.name,
        port: recipe.endpoint.port,
        healthUrl: `http://${head.managementAddress}:${recipe.endpoint.port}${recipe.endpoint.healthPath}`,
        startupTimeoutSeconds: recipe.endpoint.startupTimeoutSeconds
      }
    }
  })

export interface ResolvedInstancePlan {
  readonly declaration: InstanceDeclaration
  readonly plan: RunPlan
}

export const resolveInstancePlan = (
  catalog: Catalog,
  inventory: Inventory,
  inventoryJson: string,
  instances: InstanceCatalog,
  name: string
): Result.Result<ResolvedInstancePlan, CommandError> =>
  Result.gen(function* () {
    const declaration = yield* findInstance(instances, name)
    const plan = yield* planRun(catalog, inventory, inventoryJson, {
      recipe: declaration.recipe,
      nodes: declaration.nodes
    })
    return { declaration, plan }
  })

export const planInstance = (
  catalog: Catalog,
  inventory: Inventory,
  inventoryJson: string,
  instances: InstanceCatalog,
  name: string
): Result.Result<RunPlan, CommandError> =>
  resolveInstancePlan(
    catalog,
    inventory,
    inventoryJson,
    instances,
    name
  ).pipe(Result.map(({ plan }) => plan))

export const listRecipes = (catalog: Catalog) => ({
  schemaVersion: 1 as const,
  recipes: catalog.recipes.map((recipe) => ({
    name: recipe.name,
    recipeHash: recipe.recipeHash,
    nodeCounts: recipe.topology.nodeCounts,
    startOrder: recipe.topology.startOrder,
    platform: recipe.image.platform,
    models: recipe.models.map((model) => model.name)
  }))
})

export const listInstances = (instances: InstanceCatalog) => instances
