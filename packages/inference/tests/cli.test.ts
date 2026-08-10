import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync
} from "node:fs"
import { tmpdir } from "node:os"
import * as path from "node:path"
import test from "node:test"

const inferEntrypoint = "dist/src/entrypoints/infer.js"
const modelsEntrypoint = "dist/src/entrypoints/models.js"
const catalog = "tests/fixtures/contracts/v1/catalog.json"
const inventory = "tests/fixtures/contracts/v1/inventory.json"
const instances = "tests/fixtures/contracts/v1/instances.json"

const run = (
  entrypoint: string,
  args: ReadonlyArray<string>,
  environment: NodeJS.ProcessEnv = process.env
) =>
  spawnSync(process.execPath, [entrypoint, ...args], {
    cwd: process.cwd(),
    encoding: "utf8",
    env: environment
  })

test("recipes list emits one versioned JSON value", () => {
  const result = run(inferEntrypoint, [
    "recipes",
    "list",
    "--catalog",
    catalog,
    "--json"
  ])
  assert.equal(result.status, 0, result.stderr)
  const output = JSON.parse(result.stdout)
  assert.equal(output.schemaVersion, 1)
  assert.deepEqual(output.recipes.map((recipe: { name: string }) => recipe.name), [
    "fixture-vllm"
  ])
})

test("plan emits the checked RunPlan", () => {
  const result = run(inferEntrypoint, [
    "plan",
    "fixture",
    "--catalog",
    catalog,
    "--inventory",
    inventory,
    "--instances",
    instances,
    "--json"
  ])
  assert.equal(result.status, 0, result.stderr)
  assert.deepEqual(
    JSON.parse(result.stdout),
    JSON.parse(readFileSync("tests/fixtures/contracts/v1/run-plan.json", "utf8"))
  )
})

test("domain failures are structured in JSON mode", () => {
  const result = run(inferEntrypoint, [
    "plan",
    "missing",
    "--catalog",
    catalog,
    "--inventory",
    inventory,
    "--instances",
    instances,
    "--json"
  ])
  assert.equal(result.status, 1)
  assert.equal(result.stdout, "")
  const error = JSON.parse(result.stderr)
  assert.equal(error.schemaVersion, 1)
  assert.equal(error.code, "instance-not-found")
})

test("instances list emits the Nix-declared service catalog", () => {
  const result = run(inferEntrypoint, [
    "instances",
    "list",
    "--instances",
    instances,
    "--json"
  ])
  assert.equal(result.status, 0, result.stderr)
  const output = JSON.parse(result.stdout)
  assert.equal(output.schemaVersion, 1)
  assert.deepEqual(output.instances.map((instance: { name: string }) => instance.name), [
    "fixture"
  ])
})

test("watch once renders structured journal progress and systemd state", () => {
  const temporary = mkdtempSync(path.join(tmpdir(), "inference-watch-cli-"))
  try {
    const bin = path.join(temporary, "bin")
    mkdirSync(bin)
    const node = path.join(bin, "node-runtime")
    symlinkSync(process.execPath, node)
    const systemctl = path.join(bin, "systemctl")
    writeFileSync(
      systemctl,
      `#!${node}
process.stdout.write(${JSON.stringify(
        [
          "LoadState=loaded",
          "ActiveState=active",
          "SubState=running",
          "Result=success",
          "InvocationID=invocation-a",
          "StatusText=Cluster is healthy"
        ].join("\n") + "\n"
      )})
`
    )
    chmodSync(systemctl, 0o755)

    const startedEvent = {
      schemaVersion: 1,
      timestamp: "2026-08-09T20:00:00.000Z",
      kind: "lifecycle",
      scope: "instance",
      operation: "ensure-image",
      state: "started",
      message: "Ensuring image",
      instance: "fixture"
    }
    const completedEvent = {
      ...startedEvent,
      timestamp: "2026-08-09T20:01:00.000Z",
      state: "completed",
      message: "Image is ready"
    }
    const record = (event: typeof startedEvent, cursor: string, timestamp: string) =>
      `\u001e${JSON.stringify({
        __CURSOR: cursor,
        __REALTIME_TIMESTAMP: timestamp,
        _HOSTNAME: "spark-01",
        _SYSTEMD_INVOCATION_ID: "invocation-a",
        MESSAGE: `@infer-progress ${JSON.stringify(event)}`
      })}\n`
    const records =
      record(completedEvent, "cursor-b", "200") +
      record(startedEvent, "cursor-a", "100")
    const journalctl = path.join(bin, "journalctl")
    writeFileSync(
      journalctl,
      `#!${node}
process.stdout.write(${JSON.stringify(records)})
`
    )
    chmodSync(journalctl, 0o755)

    const result = run(
      inferEntrypoint,
      [
        "watch",
        "fixture",
        "--inventory",
        inventory,
        "--instances",
        instances,
        "--once"
      ],
      {
        ...process.env,
        PATH: `${bin}:${process.env.PATH ?? ""}`
      }
    )
    assert.equal(result.status, 0, result.stderr)
    assert.match(result.stdout, /INFER fixture  READY/)
    assert.match(result.stdout, /\[ok\] ensure-image/)
    assert.match(result.stdout, /Image is ready/)
    assert.match(result.stdout, /Cluster is healthy/)
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})

test("command-line failures are structured in JSON mode", () => {
  const result = run(inferEntrypoint, ["plan", "--json"])
  assert.equal(result.status, 2)
  assert.equal(result.stdout, "")
  const error = JSON.parse(result.stderr)
  assert.equal(error.schemaVersion, 1)
  assert.equal(error.code, "invalid-command")
  assert.equal(error.details.kind, "MissingValue")
})

test("models status reports absent archive and local artifacts", () => {
  const temporary = mkdtempSync(path.join(tmpdir(), "inference-models-cli-"))
  try {
    const archiveRoot = path.join(temporary, "archive")
    const localRoot = path.join(temporary, "local")
    mkdirSync(archiveRoot)
    mkdirSync(localRoot)
    const value = JSON.parse(readFileSync(inventory, "utf8"))
    value.modelStore = { archiveRoot, localRoot }
    const inventoryPath = path.join(temporary, "inventory.json")
    writeFileSync(inventoryPath, JSON.stringify(value))

    const result = run(modelsEntrypoint, [
      "status",
      "example/tiny-model@1111111111111111111111111111111111111111",
      "--inventory",
      inventoryPath,
      "--include",
      "weights/*",
      "--include",
      "*.json",
      "--include",
      "*.json",
      "--json"
    ])
    assert.equal(result.status, 0, result.stderr)
    const output = JSON.parse(result.stdout)
    assert.equal(output.schemaVersion, 1)
    assert.equal(output.archive.state, "absent")
    assert.equal(output.local.state, "absent")
    assert.deepEqual(output.artifact.selection.include, ["*.json", "weights/*"])
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})

test("models rejects unpinned references with a structured error", () => {
  const result = run(modelsEntrypoint, [
    "status",
    "example/tiny-model@main",
    "--json"
  ])
  assert.equal(result.status, 1)
  assert.equal(result.stdout, "")
  const error = JSON.parse(result.stderr)
  assert.equal(error.code, "invalid-model-reference")
})
