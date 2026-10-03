# Deploy from GitHub

## Deploy

Push to `main` to build and cache all configurations. Deployment requires approval.

1. After CI passes, open the **Ready to Deploy** ntfy notification.
2. In GitHub, select **Review deployments**, choose the machines, then
   **Approve and deploy**.
3. Reject the other machines or leave them waiting.

ntfy reports each machine's result. Rejected jobs appear as failed. Waiting
approvals expire after 30 days and do not block new builds.

For Spark, approve the workers first. Wait for success before approving
`spark-01`. You must enforce this order manually.

Only inventory-backed NixOS hosts deploy. MicroVMs and Darwin are build-only.

## Retry or roll back

In **Actions → Deploy → Run workflow**, use branch `main` and enter:

- **build_run_id:** a successful main CI run ID.
- **machines:** names such as `kiwi,portal`; leave empty for all machines.

The latest attempt must have passed and have a retained release manifest.
Approval is still required; deployment uses that build's exact cached paths.
Manifests last 45 days; cached binaries last 90 days. A system rollback does not
restore application data or undo database migrations.

## Set up a NixOS host

Set the GitHub secrets `CACHIX_ACTIVATE_TOKEN` and `NTFY_TOPIC`. For each host:

1. Generate its agent token and install the configuration:

   ```sh
   nix run .#clan -- vars generate <host> --generator cachix-deploy
   nix run .#clan -- machines update <host>
   ```

2. Commit the encrypted Clan vars and check that the agent is connected in Cachix.
3. Create a GitHub environment with the host's exact name. Require operator
   approval, allow self-review, disable admin bypass, and permit only `main`.

Set the GitHub variable `CACHIX_DEPLOY_ENABLED=true` to enable approval requests.
Unset it or set it to `false` for build-only operation.

## Update a Darwin host

Run these commands on the host, from its configuration checkout:

```sh
git pull --ff-only
just sync
```
