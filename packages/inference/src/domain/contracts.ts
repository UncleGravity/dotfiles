import { Schema } from "effect"

const nonEmpty = Schema.NonEmptyString
const absolutePath = Schema.String.pipe(
  Schema.pattern(/^\//, { description: "an absolute path" })
)
export const RelativePath = Schema.String.pipe(
  Schema.filter(
    (value) =>
      value.length > 0 &&
      !value.startsWith("/") &&
      !value.split("/").includes(".."),
    { description: "a non-empty relative path without '..' segments" }
  )
)
export const SelectionPattern = Schema.String.pipe(
  Schema.filter(
    (value) =>
      value.length > 0 &&
      !value.startsWith("/") &&
      !value.split("/").includes(".."),
    { description: "a relative selection pattern without '..' segments" }
  )
)
const nodeName = Schema.String.pipe(
  Schema.pattern(/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/, {
    description: "a kebab-case node name"
  })
)
const recipeName = Schema.String.pipe(
  Schema.pattern(/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/, {
    description: "a kebab-case recipe name"
  })
)
export const Sha256 = Schema.String.pipe(
  Schema.pattern(/^[0-9a-f]{64}$/, { description: "a lowercase SHA-256 hash" })
)
export const OciDigest = Schema.String.pipe(
  Schema.pattern(/^sha256:[0-9a-f]{64}$/, {
    description: "a lowercase OCI SHA-256 digest"
  })
)
export const Commit = Schema.String.pipe(
  Schema.pattern(/^[0-9a-f]{40}$/, {
    description: "a lowercase Hugging Face commit SHA"
  })
)
export const Repository = Schema.String.pipe(
  Schema.pattern(/^[^/\s]+\/[^/\s]+$/, {
    description: "a Hugging Face repository in ORG/REPO form"
  })
)
const positiveInt = Schema.Number.pipe(Schema.int(), Schema.greaterThan(0))
const nonNegativeInt = Schema.Number.pipe(
  Schema.int(),
  Schema.greaterThanOrEqualTo(0)
)
const port = Schema.Number.pipe(Schema.int(), Schema.between(1, 65535))
const stringMap = Schema.Record({ key: Schema.String, value: Schema.String })
const rfc3339 = Schema.String.pipe(
  Schema.pattern(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/, {
    description: "a UTC RFC 3339 timestamp"
  })
)
export const Platform = Schema.Literal("linux/amd64", "linux/arm64")
export type Platform = typeof Platform.Type

export const ModelSelection = Schema.Struct({
  include: Schema.Array(SelectionPattern),
  exclude: Schema.Array(SelectionPattern)
})
export type ModelSelection = typeof ModelSelection.Type

export const ModelSpec = Schema.Struct({
  name: nonEmpty,
  repo: Repository,
  revision: Commit,
  selection: ModelSelection
})
export type ModelSpec = typeof ModelSpec.Type

export const ImageSpec = Schema.Struct({
  platform: Platform,
  context: absolutePath,
  containerfile: absolutePath,
  buildArgs: stringMap,
  buildHash: Sha256
})
export type ImageSpec = typeof ImageSpec.Type

export const TopologySpec = Schema.Struct({
  nodeCounts: Schema.Array(positiveInt),
  startOrder: Schema.Literal("head-first", "workers-first", "parallel")
})
export type TopologySpec = typeof TopologySpec.Type

export const BindMount = Schema.Struct({
  sourcePath: absolutePath,
  targetPath: absolutePath,
  readOnly: Schema.Boolean
})
export type BindMount = typeof BindMount.Type

export const ContainerSpec = Schema.Struct({
  devices: Schema.Array(nonEmpty),
  extraOptions: Schema.Array(nonEmpty),
  environment: stringMap,
  args: Schema.Array(Schema.String),
  mounts: Schema.Array(BindMount)
})
export type ContainerSpec = typeof ContainerSpec.Type

export const EndpointSpec = Schema.Struct({
  port,
  healthPath: absolutePath,
  startupTimeoutSeconds: positiveInt
})
export type EndpointSpec = typeof EndpointSpec.Type

export const Recipe = Schema.Struct({
  schemaVersion: Schema.Literal(1),
  name: recipeName,
  recipeHash: Sha256,
  models: Schema.NonEmptyArray(ModelSpec),
  image: ImageSpec,
  topology: TopologySpec,
  container: ContainerSpec,
  endpoint: EndpointSpec
})
export type Recipe = typeof Recipe.Type

export const Catalog = Schema.Struct({
  schemaVersion: Schema.Literal(1),
  recipes: Schema.Array(Recipe)
})
export type Catalog = typeof Catalog.Type

export const FabricAddresses = Schema.Struct({
  fabric0: Schema.optional(nonEmpty),
  fabric1: Schema.optional(nonEmpty)
})

export const InventoryNode = Schema.Struct({
  name: nodeName,
  platform: Platform,
  managementAddress: nonEmpty,
  fabric: FabricAddresses
})
export type InventoryNode = typeof InventoryNode.Type

export const Inventory = Schema.Struct({
  schemaVersion: Schema.Literal(1),
  protocolVersion: Schema.Literal(1),
  localNode: nodeName,
  controlNode: nodeName,
  modelStore: Schema.Struct({
    archiveRoot: absolutePath,
    localRoot: absolutePath
  }),
  registry: Schema.Struct({
    endpoint: nonEmpty
  }),
  nodes: Schema.NonEmptyArray(InventoryNode)
})
export type Inventory = typeof Inventory.Type

export const InstanceDeclaration = Schema.Struct({
  name: recipeName,
  recipe: recipeName,
  nodes: Schema.NonEmptyArray(nodeName),
  autoStart: Schema.Boolean
})
export type InstanceDeclaration = typeof InstanceDeclaration.Type

export const InstanceCatalog = Schema.Struct({
  schemaVersion: Schema.Literal(1),
  instances: Schema.Array(InstanceDeclaration)
})
export type InstanceCatalog = typeof InstanceCatalog.Type

export const ArtifactIdentity = Schema.Struct({
  source: Schema.Literal("hf"),
  repo: Repository,
  revision: Commit,
  selection: ModelSelection,
  selectionHash: Sha256,
  relativePath: RelativePath
})
export type ArtifactIdentity = typeof ArtifactIdentity.Type

export const ModelManifestFile = Schema.Struct({
  path: RelativePath,
  size: nonNegativeInt,
  sha256: Sha256
})
export type ModelManifestFile = typeof ModelManifestFile.Type

export const ModelManifest = Schema.Struct({
  schemaVersion: Schema.Literal(1),
  source: Schema.Literal("hf"),
  repo: Repository,
  revision: Commit,
  selection: ModelSelection,
  selectionHash: Sha256,
  files: Schema.NonEmptyArray(ModelManifestFile),
  createdAt: rfc3339
})
export type ModelManifest = typeof ModelManifest.Type

export const ArtifactLocationStatus = Schema.Struct({
  state: Schema.Literal("absent", "staging", "locked", "ready", "invalid"),
  path: absolutePath,
  stagingPath: absolutePath,
  issues: Schema.Array(nonEmpty),
  manifest: Schema.optional(
    Schema.Struct({
      createdAt: rfc3339,
      fileCount: positiveInt,
      totalSize: nonNegativeInt
    })
  )
})
export type ArtifactLocationStatus = typeof ArtifactLocationStatus.Type

export type ReadyArtifactLocation = Omit<
  ArtifactLocationStatus,
  "manifest" | "state"
> & {
  readonly state: "ready"
  readonly manifest: NonNullable<ArtifactLocationStatus["manifest"]>
}

export const ModelStatus = Schema.Struct({
  schemaVersion: Schema.Literal(1),
  artifact: ArtifactIdentity,
  archive: ArtifactLocationStatus,
  local: ArtifactLocationStatus
})
export type ModelStatus = typeof ModelStatus.Type

export const ModelEnsureResult = Schema.Struct({
  schemaVersion: Schema.Literal(1),
  artifact: ArtifactIdentity,
  source: Schema.Union(
    Schema.Struct({ kind: Schema.Literal("archive") }),
    Schema.Struct({ kind: Schema.Literal("node"), node: nodeName })
  ),
  local: ArtifactLocationStatus
})
export type ModelEnsureResult = typeof ModelEnsureResult.Type

export type ReadyModelEnsureResult = Omit<ModelEnsureResult, "local"> & {
  readonly local: ReadyArtifactLocation
}

export const ImageStatus = Schema.Struct({
  schemaVersion: Schema.Literal(1),
  recipe: Schema.Struct({
    name: recipeName,
    buildHash: Sha256,
    platform: Platform
  }),
  registry: Schema.Struct({
    state: Schema.Literal("absent", "ready", "unavailable"),
    reference: nonEmpty,
    digest: Schema.optional(OciDigest),
    issues: Schema.Array(nonEmpty)
  }),
  local: Schema.Struct({
    state: Schema.Literal("absent", "ready", "unknown"),
    reference: Schema.optional(nonEmpty),
    issues: Schema.Array(nonEmpty)
  })
})
export type ImageStatus = typeof ImageStatus.Type

export type ReadyImageStatus = Omit<ImageStatus, "local" | "registry"> & {
  readonly registry: Omit<ImageStatus["registry"], "digest" | "state"> & {
    readonly state: "ready"
    readonly digest: string
  }
  readonly local: Omit<ImageStatus["local"], "reference" | "state"> & {
    readonly state: "ready"
    readonly reference: string
  }
}

export const PlannedModel = Schema.Struct({
  name: nonEmpty,
  artifact: ArtifactIdentity,
  mount: Schema.Struct({
    sourcePath: absolutePath,
    targetPath: absolutePath,
    readOnly: Schema.Literal(true)
  })
})
export type PlannedModel = typeof PlannedModel.Type

export const NodePlan = Schema.Struct({
  node: nodeName,
  role: Schema.Literal("single", "head", "worker"),
  rank: Schema.Number.pipe(Schema.int(), Schema.greaterThanOrEqualTo(0)),
  container: Schema.Struct({
    devices: Schema.Array(nonEmpty),
    network: Schema.Literal("host"),
    extraOptions: Schema.Array(nonEmpty),
    environment: stringMap,
    args: Schema.Array(Schema.String),
    mounts: Schema.Array(BindMount)
  })
})
export type NodePlan = typeof NodePlan.Type

export const RunPlan = Schema.Struct({
  schemaVersion: Schema.Literal(1),
  recipe: Schema.Struct({
    name: recipeName,
    hash: Sha256
  }),
  inventoryHash: Sha256,
  startOrder: Schema.Literal("head-first", "workers-first", "parallel"),
  nodes: Schema.NonEmptyArray(nodeName),
  head: nodeName,
  models: Schema.NonEmptyArray(PlannedModel),
  image: Schema.Struct({
    platform: Platform,
    buildHash: Sha256
  }),
  nodePlans: Schema.NonEmptyArray(NodePlan),
  endpoint: Schema.Struct({
    node: nodeName,
    port,
    healthUrl: nonEmpty,
    startupTimeoutSeconds: positiveInt
  })
})
export type RunPlan = typeof RunPlan.Type

export const RemoteUnitStatus = Schema.Struct({
  schemaVersion: Schema.Literal(1),
  instance: recipeName,
  node: nodeName,
  loadState: nonEmpty,
  activeState: nonEmpty,
  subState: nonEmpty,
  result: nonEmpty
})
export type RemoteUnitStatus = typeof RemoteUnitStatus.Type

export const RecipeList = Schema.Struct({
  schemaVersion: Schema.Literal(1),
  recipes: Schema.Array(
    Schema.Struct({
      name: recipeName,
      recipeHash: Sha256,
      nodeCounts: Schema.Array(positiveInt),
      startOrder: Schema.Literal("head-first", "workers-first", "parallel"),
      platform: Platform,
      models: Schema.Array(nonEmpty)
    })
  )
})
export type RecipeList = typeof RecipeList.Type
