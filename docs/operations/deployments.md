# Deploy from Github

## How?

- CI builds every config on PRs and pushes to `main`.
- NixOS hosts listed in `clan.inventory.machines` **auto-deploy** when `main` builds pass.
- Everything else (microVMs, Darwin) is **build-only**.

## What you need

Three things control Cachix Deploy:

| Thing | Lives in | What it does |
|---|---|---|
| `cachix-deploy` var | Clan vars | Gives NixOS hosts their agent token |
| `CACHIX_ACTIVATE_TOKEN` | GitHub secret | Authorizes deployments |
| `CACHIX_DEPLOY_ENABLED` | GitHub variable | `true` = deploys on. Unset or `false` = build only |

## Enroll a NixOS host

1. Generate the agent token:

   ```sh
   nix run .#clan -- vars generate <host> --generator cachix-deploy
   ```

2. Install the host config:

   ```sh
   nix run .#clan -- machines update <host>
   ```

3. Commit the new encrypted Clan vars.
4. Check the agent shows as connected in the Cachix workspace.
5. Only now set `CACHIX_DEPLOY_ENABLED=true`.

## Update a Darwin host

Do this on the host, from your config checkout:

```sh
git pull --ff-only
just sync
```
