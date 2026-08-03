import { FileSystem } from "@effect/platform"
import { Effect } from "effect"
import { LocalLock } from "../adapters/local-lock.js"
import { ProcessRunner } from "../adapters/process-runner.js"
import type {
  Catalog,
  ImageStatus,
  Inventory,
  Recipe
} from "../domain/contracts.js"
import { CommandError } from "../domain/errors.js"

const digestPattern = /^sha256:[0-9a-f]{64}$/

const findRecipe = (
  catalog: Catalog,
  name: string
): Effect.Effect<Recipe, CommandError> => {
  const recipe = catalog.recipes.find((candidate) => candidate.name === name)
  return recipe === undefined
    ? Effect.fail(
        new CommandError({
          code: "recipe-not-found",
          message: `Recipe '${name}' does not exist in this deployment`,
          details: { recipe: name }
        })
      )
    : Effect.succeed(recipe)
}

const tagReference = (inventory: Inventory, recipe: Recipe): string =>
  `${inventory.registry.endpoint}/infer/${recipe.name}:build-${recipe.image.buildHash}`

const digestReference = (
  inventory: Inventory,
  recipe: Recipe,
  digest: string
): string =>
  `${inventory.registry.endpoint}/infer/${recipe.name}@${digest}`

type RegistryResolution =
  | { readonly state: "absent" }
  | { readonly state: "ready"; readonly digest: string }
  | { readonly state: "unavailable"; readonly issue: string }

const missingManifest = (output: string): boolean => {
  const normalized = output.toLowerCase()
  return [
    "manifest unknown",
    "name unknown",
    "status code: 404",
    "statuscode: 404"
  ].some((message) => normalized.includes(message))
}

const resolveRegistry = (
  reference: string
): Effect.Effect<RegistryResolution, CommandError, ProcessRunner> =>
  Effect.gen(function* () {
    const runner = yield* ProcessRunner
    const outcome = yield* runner.probe({
      command: "skopeo",
      args: [
        "inspect",
        "--tls-verify=false",
        "--format",
        "{{.Digest}}",
        `docker://${reference}`
      ]
    })

    if (outcome.exitCode !== 0) {
      const output = `${outcome.stderr}\n${outcome.stdout}`
      return missingManifest(output)
        ? { state: "absent" as const }
        : {
            state: "unavailable" as const,
            issue: "the registry tag could not be inspected"
          }
    }

    const digest = outcome.stdout.trim()
    return digestPattern.test(digest)
      ? { state: "ready" as const, digest }
      : {
          state: "unavailable" as const,
          issue: "the registry returned an invalid image digest"
        }
  })

const localImageExists = (
  reference: string
): Effect.Effect<boolean, CommandError, ProcessRunner> =>
  Effect.gen(function* () {
    const runner = yield* ProcessRunner
    const outcome = yield* runner.probe({
      command: "podman",
      args: ["image", "exists", reference]
    })
    if (outcome.exitCode === 0) return true
    if (outcome.exitCode === 1) return false
    return yield* Effect.fail(
      new CommandError({
        code: "image-status-failed",
        message: "Podman could not inspect the local image store",
        details: {
          reference,
          exitCode: outcome.exitCode,
          signal: outcome.signal
        }
      })
    )
  })

const statusFor = (
  inventory: Inventory,
  recipe: Recipe
): Effect.Effect<ImageStatus, CommandError, ProcessRunner> =>
  Effect.gen(function* () {
    const reference = tagReference(inventory, recipe)
    const registry = yield* resolveRegistry(reference)

    if (registry.state !== "ready") {
      return {
        schemaVersion: 1 as const,
        recipe: {
          name: recipe.name,
          buildHash: recipe.image.buildHash,
          platform: recipe.image.platform
        },
        registry: {
          state: registry.state,
          reference,
          issues:
            registry.state === "unavailable" ? [registry.issue] : []
        },
        local: {
          state: registry.state === "unavailable" ? "unknown" : "absent",
          issues:
            registry.state === "unavailable"
              ? ["the immutable image reference is not known"]
              : []
        }
      }
    }

    const immutableReference = digestReference(
      inventory,
      recipe,
      registry.digest
    )
    const localReady = yield* localImageExists(immutableReference)
    return {
      schemaVersion: 1 as const,
      recipe: {
        name: recipe.name,
        buildHash: recipe.image.buildHash,
        platform: recipe.image.platform
      },
      registry: {
        state: "ready" as const,
        reference,
        digest: registry.digest,
        issues: []
      },
      local: {
        state: localReady ? ("ready" as const) : ("absent" as const),
        reference: immutableReference,
        issues: []
      }
    }
  })

export const imageStatus = (
  catalog: Catalog,
  inventory: Inventory,
  recipeName: string
): Effect.Effect<ImageStatus, CommandError, ProcessRunner> =>
  findRecipe(catalog, recipeName).pipe(
    Effect.flatMap((recipe) => statusFor(inventory, recipe))
  )

const buildAndPublish = (
  recipe: Recipe,
  reference: string
): Effect.Effect<void, CommandError, ProcessRunner> =>
  Effect.gen(function* () {
    const runner = yield* ProcessRunner
    const buildArguments = Object.entries(recipe.image.buildArgs)
      .sort(([left], [right]) => left.localeCompare(right))
      .flatMap(([name, value]) => ["--build-arg", `${name}=${value}`])

    yield* runner.run({
      command: "podman",
      args: [
        "build",
        "--pull=missing",
        "--platform",
        recipe.image.platform,
        "--file",
        recipe.image.containerfile,
        ...buildArguments,
        "--tag",
        reference,
        recipe.image.context
      ]
    })
    yield* runner.run({
      command: "podman",
      args: ["push", "--tls-verify=false", reference]
    })
  })

export const ensureImage = (
  catalog: Catalog,
  inventory: Inventory,
  recipeName: string
): Effect.Effect<
  ImageStatus,
  CommandError,
  FileSystem.FileSystem | LocalLock | ProcessRunner
> =>
  Effect.gen(function* () {
    const recipe = yield* findRecipe(catalog, recipeName)
    const reference = tagReference(inventory, recipe)
    const fs = yield* FileSystem.FileSystem
    const lock = yield* LocalLock
    const runner = yield* ProcessRunner
    const lockRoot = `${inventory.modelStore.localRoot}/.locks/images`
    const lockPath = `${lockRoot}/${recipe.name}-${recipe.image.buildHash}.lock`
    yield* fs.makeDirectory(lockRoot, { recursive: true }).pipe(
      Effect.mapError(
        () =>
          new CommandError({
            code: "image-store-io-failed",
            message: `Unable to create image lock directory '${lockRoot}'`,
            details: { path: lockRoot }
          })
      )
    )

    const prepareRegistry = Effect.gen(function* () {
      const resolution = yield* resolveRegistry(reference)
      if (resolution.state === "ready") return resolution.digest
      if (resolution.state === "unavailable") {
        return yield* Effect.fail(
          new CommandError({
            code: "image-registry-unavailable",
            message: "The recipe image tag could not be inspected safely",
            details: { reference }
          })
        )
      }

      yield* buildAndPublish(recipe, reference)
      const published = yield* resolveRegistry(reference)
      if (published.state !== "ready") {
        return yield* Effect.fail(
          new CommandError({
            code: "image-publication-failed",
            message: "The published image tag did not resolve to a digest",
            details: { reference }
          })
        )
      }
      return published.digest
    })

    const initial = yield* resolveRegistry(reference)
    const digest =
      initial.state === "ready"
        ? initial.digest
        : initial.state === "unavailable"
          ? yield* Effect.fail(
              new CommandError({
                code: "image-registry-unavailable",
                message: "The recipe image tag could not be inspected safely",
                details: { reference }
              })
            )
          : inventory.localNode === inventory.controlNode
            ? yield* Effect.scoped(
                lock.acquire(lockPath).pipe(Effect.zipRight(prepareRegistry))
              )
            : yield* Effect.fail(
                new CommandError({
                  code: "image-not-published",
                  message: `Recipe image '${recipe.name}' has not been published by '${inventory.controlNode}'`,
                  details: {
                    reference,
                    localNode: inventory.localNode,
                    controlNode: inventory.controlNode
                  }
                })
              )

    const immutableReference = digestReference(inventory, recipe, digest)
    if (!(yield* localImageExists(immutableReference))) {
      yield* runner.run({
        command: "podman",
        args: ["pull", "--tls-verify=false", immutableReference]
      })
    }
    if (!(yield* localImageExists(immutableReference))) {
      return yield* Effect.fail(
        new CommandError({
          code: "image-ensure-failed",
          message: "Podman did not retain the requested immutable image",
          details: { reference: immutableReference }
        })
      )
    }

    return yield* statusFor(inventory, recipe)
  })
