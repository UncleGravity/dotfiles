import assert from "node:assert/strict"
import {
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync
} from "node:fs"
import { tmpdir } from "node:os"
import * as path from "node:path"
import test from "node:test"
import { NodeContext } from "@effect/platform-node"
import { Effect, Either, Schema } from "effect"
import { loadContract } from "../src/adapters/contract-files.js"
import {
  Catalog,
  InstanceCatalog,
  Inventory,
  ModelManifest,
  RunPlan
} from "../src/domain/contracts.js"
import { planInstance, planRun } from "../src/domain/planner.js"

const fixture = (name: string): string =>
  readFileSync(`tests/fixtures/contracts/v1/${name}`, "utf8")

const decode = <A, I>(schema: Schema.Schema<A, I, never>, json: string): A =>
  Schema.decodeUnknownSync(Schema.parseJson(schema), {
    errors: "all",
    onExcessProperty: "error"
  })(json)

const catalogJson = fixture("catalog.json")
const inventoryJson = fixture("inventory.json")
const catalog = decode(Catalog, catalogJson)
const inventory = decode(Inventory, inventoryJson)
const instances = decode(InstanceCatalog, fixture("instances.json"))

test("strict contracts reject unknown fields", () => {
  const invalid = JSON.stringify({ ...JSON.parse(catalogJson), unknown: true })
  assert.throws(() => decode(Catalog, invalid))
})

test("the v1 model manifest fixture decodes strictly", () => {
  const manifest = decode(ModelManifest, fixture("model-manifest.json"))
  assert.equal(manifest.schemaVersion, 1)
  assert.equal(manifest.files[0].path, "config.json")
})

test("planning is deterministic and matches the checked contract", () => {
  const first = planInstance(
    catalog,
    inventory,
    inventoryJson,
    instances,
    "fixture"
  )
  const second = planInstance(
    catalog,
    inventory,
    inventoryJson,
    instances,
    "fixture"
  )

  assert.ok(Either.isRight(first))
  assert.ok(Either.isRight(second))
  assert.deepEqual(first.right, second.right)

  const expected = decode(RunPlan, fixture("run-plan.json"))
  assert.deepEqual(first.right, expected)
})

test("planning rejects undeclared instances", () => {
  const result = planInstance(
    catalog,
    inventory,
    inventoryJson,
    instances,
    "missing"
  )
  assert.ok(Either.isLeft(result))
  assert.equal(result.left.code, "instance-not-found")
})

test("ordered nodes select the head and assign stable ranks", () => {
  const result = planRun(catalog, inventory, inventoryJson, {
    recipe: "fixture-vllm",
    nodes: ["spark-02", "spark-01"]
  })

  assert.ok(Either.isRight(result))
  assert.deepEqual(result.right.nodes, ["spark-02", "spark-01"])
  assert.equal(result.right.head, "spark-02")
  assert.deepEqual(
    result.right.nodePlans.map(({ node, rank, role }) => ({ node, rank, role })),
    [
      { node: "spark-02", rank: 0, role: "head" },
      { node: "spark-01", rank: 1, role: "worker" }
    ]
  )
})

test("multi-node planning requires an explicit ordered node selection", () => {
  const result = planRun(catalog, inventory, inventoryJson, {
    recipe: "fixture-vllm"
  })

  assert.ok(Either.isLeft(result))
  assert.equal(result.left.code, "node-selection-required")
})

test("planning rejects duplicate nodes", () => {
  const result = planRun(catalog, inventory, inventoryJson, {
    recipe: "fixture-vllm",
    nodes: ["spark-01", "spark-01"]
  })

  assert.ok(Either.isLeft(result))
  assert.equal(result.left.code, "duplicate-node")
})

test("planning rejects invalid recipes, selections, and node capabilities", () => {
  const node0 = inventory.nodes[0]!
  const node1 = inventory.nodes[1]!
  const node2 = {
    ...node1,
    name: "spark-03",
    managementAddress: "192.168.1.33",
    fabric: { fabric0: "10.100.0.3", fabric1: "10.100.1.3" }
  }
  const cases: ReadonlyArray<{
    readonly expected: string
    readonly inventory?: Inventory
    readonly recipe?: string
    readonly nodes?: ReadonlyArray<string>
  }> = [
    { recipe: "missing", nodes: [node0.name, node1.name], expected: "recipe-not-found" },
    { nodes: [node0.name, "missing"], expected: "unknown-node" },
    { nodes: [], expected: "empty-node-selection" },
    {
      inventory: { ...inventory, nodes: [node0, node1, node2] },
      nodes: [node0.name, node1.name, node2.name],
      expected: "unsupported-node-count"
    },
    {
      inventory: {
        ...inventory,
        nodes: [
          { ...node0, platform: "linux/amd64" },
          node1
        ]
      },
      nodes: [node0.name, node1.name],
      expected: "platform-mismatch"
    },
    {
      inventory: {
        ...inventory,
        nodes: [
          node0,
          { ...node1, fabric: { fabric1: node1.fabric.fabric1 } }
        ]
      },
      nodes: [node0.name, node1.name],
      expected: "missing-fabric-address"
    }
  ]

  for (const testCase of cases) {
    const result = planRun(
      catalog,
      testCase.inventory ?? inventory,
      inventoryJson,
      {
        recipe: testCase.recipe ?? "fixture-vllm",
        ...(testCase.nodes === undefined ? {} : { nodes: testCase.nodes })
      }
    )
    assert.ok(Either.isLeft(result), testCase.expected)
    assert.equal(result.left.code, testCase.expected)
  }
})

test("planning rejects structurally inconsistent inventories", () => {
  const node0 = inventory.nodes[0]!
  const node1 = inventory.nodes[1]!
  const cases: ReadonlyArray<Inventory> = [
    { ...inventory, nodes: [node0, node0] },
    { ...inventory, nodes: [node1, node0] },
    { ...inventory, localNode: "missing" },
    { ...inventory, controlNode: "missing" }
  ]

  for (const invalid of cases) {
    const result = planRun(catalog, invalid, inventoryJson, {
      recipe: "fixture-vllm",
      nodes: [node0.name, node1.name]
    })
    assert.ok(Either.isLeft(result))
    assert.equal(result.left.code, "invalid-inventory")
  }
})

test("contract files preserve raw input and classify read and schema errors", async () => {
  const temporary = mkdtempSync(path.join(tmpdir(), "inference-contract-"))
  const validPath = path.join(temporary, "inventory.json")
  const invalidPath = path.join(temporary, "invalid.json")
  writeFileSync(validPath, inventoryJson)
  writeFileSync(
    invalidPath,
    JSON.stringify({ ...JSON.parse(inventoryJson), unexpected: true })
  )

  const run = <A, E>(effect: Effect.Effect<A, E, NodeContext.NodeContext>) =>
    Effect.runPromise(effect.pipe(Effect.provide(NodeContext.layer)))

  try {
    const loaded = await run(
      loadContract(validPath, "Inventory", Inventory)
    )
    assert.equal(loaded.raw, inventoryJson)
    assert.deepEqual(loaded.value, inventory)

    const invalid = await run(
      Effect.either(loadContract(invalidPath, "Inventory", Inventory))
    )
    assert.ok(Either.isLeft(invalid))
    assert.equal(invalid.left.code, "invalid-contract")
    assert.equal(invalid.left.details?.path, invalidPath)

    const missingPath = path.join(temporary, "missing.json")
    const missing = await run(
      Effect.either(loadContract(missingPath, "Inventory", Inventory))
    )
    assert.ok(Either.isLeft(missing))
    assert.equal(missing.left.code, "contract-read-failed")
    assert.equal(missing.left.details?.path, missingPath)
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})
