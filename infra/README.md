# Infrastructure

- `portal/` OpenTofu stack for Portal's Hetzner and Cloudflare
  resources, including its encrypted state.
- `mikrotik-crs804/` RouterOS configuration and runbook for the
  DGX Spark fabric switch.

Use `just infra <command>` for the Portal stack. Follow the switch runbook for
RouterOS changes.
