# Inference design documentation

## Status

These documents describe the current architecture and mark future Spark work
where it matters. [Implementation](implementation.md) distinguishes completed,
implemented-but-unvalidated, and future milestones.

## Reading guide

| Document | Question it answers |
| --- | --- |
| [Architecture](architecture.md) | What are the system boundaries, deployments, components, and invariants? |
| [Artifacts](artifacts.md) | How are models and OCI images identified, prepared, verified, and distributed? |
| [Recipes](recipes.md) | How is a complete inference workload declared in Nix? |
| [Execution](execution.md) | How does a Nix instance become a systemd service and recover from failure? |
| [Implementation](implementation.md) | How will Nix, Effect, and existing host tools implement the design? |

Read `architecture.md` first for the overview. Recipe authors can then go
directly to `recipes.md`; runtime work generally needs `execution.md` and
`implementation.md`; artifact preparation work belongs in `artifacts.md`.

## Ownership convention

Every behavioral fact has one canonical document. Other documents may
summarize it and link to its owner, but should not maintain a second detailed
definition.

- Model manifests and image identity belong to `artifacts.md`.
- Recipe and catalog contracts belong to `recipes.md`.
- Instance planning and service behavior belong to `execution.md`.
- Technology, source layout, packaging, and delivery order belong to
  `implementation.md`.

Deferred decisions stay with the document that owns the affected behavior.
Add an operations guide when there is a deployed system to operate, and add a
decision log only when a decision needs rationale beyond these design docs.
