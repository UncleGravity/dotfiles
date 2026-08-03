import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import { Either, Schema } from "effect"
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
