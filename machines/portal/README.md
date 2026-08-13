# portal

[Pangolin](https://pangolin.net/) gateway for `angel.pizza`, hosted on Hetzner Cloud.

| Layer | Managed by | State |
|---|---|---|
| Server, IPv4 address, firewall, DNS | OpenTofu in `infra/` | Encrypted `infra/terraform.tfstate` |
| NixOS and Pangolin services | This flake | Git |
| Pangolin application data | `/var/lib/pangolin` | Portal root disk |

## Provision

OpenTofu manages the Hetzner VM, its persistent IPv4 address, firewall, SSH
key, and reverse DNS. It also manages the Cloudflare records for
`angel.pizza`, `pangolin.angel.pizza`, and the wildcard service domain.
NixOS and Pangolin are installed separately in the following steps.

```sh
just infra init   # Install the configured providers.
just infra plan   # Preview changes to Hetzner and Cloudflare.
just infra apply  # Apply the reviewed changes.
```

Commit `infra/terraform.tfstate` and `infra/.terraform.lock.hcl` after an
apply. The state is encrypted by the OpenTofu configuration.

Install NixOS using the reported IPv4 address:

```sh
PORTAL_IPV4=$(just infra "output -raw portal_ipv4") # retrieve server IP
just provision portal "root@$PORTAL_IPV4" # install NixOS
```

Provisioning erases the target disk. It injects the stored key from
`secrets/host-keys/`, preserving the host's SSH and SOPS identity across
reinstalls.

## Bootstrap

Open `https://pangolin.angel.pizza`, create the administrator and organization,
and confirm the `angel.pizza` domain. Create a site for each Newt connector and
store its credentials in that host's SOPS file before deploying it.

## Deploy

Deploy configuration changes over the `portal` SSH host:

```sh
just deploy portal
```

Edit Portal-specific secrets with:

```sh
sops edit machines/portal/secrets/secrets.yaml
```

## Replace

Replace the VM while retaining its public IPv4 address:

```sh
just infra apply -replace=hcloud_server.portal
PORTAL_IPV4=$(just infra "output -raw portal_ipv4")
just provision portal "root@$PORTAL_IPV4"
```

The public IPv4 address and stored SSH identity survive replacement.
`/var/lib/pangolin` does not. There is currently no automated backup, so a
replacement requires either restoring that directory or bootstrapping
Pangolin again and updating the Newt credentials.
