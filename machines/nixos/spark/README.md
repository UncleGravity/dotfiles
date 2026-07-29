# DGX Spark cluster

Four DGX Sparks on a MikroTik CRS804 fabric, managed from Banana. `spark-01`
is the controller (DGX dashboard, staging point); the others are workers.
Based on the [ktrinh-anduril nixos-dgx-spark fork](https://github.com/ktrinh-anduril/nixos-dgx-spark),
with local kernel compatibility fixes in `kernel.nix`.

## Inventory

Declared in `nodes.nix` (single source of truth for the install script and
per-node config).

| Node | Management (DHCP reservation) | Fabric rail 0 | Fabric rail 1 | Role |
| --- | --- | --- | --- | --- |
| `spark-01` | `192.168.1.31` | `10.100.0.1` | `10.100.1.1` | controller |
| `spark-02` | `192.168.1.32` | `10.100.0.2` | `10.100.1.2` | worker |
| `spark-03` | `192.168.1.33` | `10.100.0.3` | `10.100.1.3` | worker |
| `spark-04` | `192.168.1.34` | `10.100.0.4` | `10.100.1.4` | worker |

The management NIC (`enP7s7`, Realtek RTL8127, `r8127` vendor driver) uses
DHCP; the reservations give deterministic install/recovery addresses while
day-to-day access uses `<node>.local` via avahi. Both ConnectX-7 rails are
untagged switch access ports (VLAN 100) with MTU 9000 and no default route —
see `mikrotik-crs804/configuration.rsc` for the switch side.

## SSH keys — the three domains

1. **Operator keys** (who can log in): `modules/common/ssh-keys.nix`,
   authorized on every host declaratively. No per-machine key steps, ever.
2. **Host keys** (machine identity): generated once on Banana and stored in
   `secrets/host-keys/` with the private key encrypted only to the operator.
   The installer stages this identity into the new system; factory and USB
   installer host keys are never promoted.
3. **sops age identity** (what secrets it reads): derived from the escrowed
   public host key and registered in `.sops.yaml` before installation. The
   installed system can therefore decrypt its assigned secrets on first boot.

## Installing a node (from factory)

kexec does not work on this hardware — `kexec -e` resets the SoC back to
firmware and the machine reboots into the old OS — so installation goes
through a USB stick with the stock NixOS minimal aarch64 ISO.

1. **On DGX OS** (its only job): finish factory setup and firmware updates:
   `sudo fwupdmgr refresh && sudo fwupdmgr update`.
2. **BIOS**: disable Secure Boot (NixOS bootloader is unsigned).
3. **Inventory**: capture the `enP7s7` MAC, add the router DHCP reservation,
   add the node to `nodes.nix`, enable its fabric port on the MikroTik.
4. **Identity**: create the node's permanent identity on Banana:
   ```bash
   just host-key create spark-0N
   ```
   Replace the node's existing `.sops.yaml` anchor with the printed host Age
   identity, then update and verify the affected secrets:
   ```bash
   just sops-update-keys
   just host-key check spark-0N
   ```
   Commit and back up the new host-key bundle, anchor, and rekeyed SOPS files
   before erasing the factory OS. This repository copy is the recovery path.
5. **Boot the USB stick.** On the console: `sudo passwd root` (temporary) and
   confirm `ip -br addr` shows the reserved address.
6. **From Banana**: `ssh-keygen -R <ip> && ssh-copy-id root@<ip>`.
7. ```bash
   just spark-install spark-0N
   ```
   Disko creates a 1 GiB ESP plus ext4 root. The system (including the NVIDIA
   kernel, 30-60 min) builds on the Spark itself, then it reboots into NixOS.
   Pull the stick during the reboot. The installed system presents the
   escrowed identity, not the temporary USB identity.
8. **Verify the first boot identity** before accepting it into `known_hosts`.
   These two commands must report the same fingerprint:
   ```bash
   ssh-keygen -lf secrets/host-keys/spark-0N.pub
   ssh-keyscan -t ed25519 spark-0N.local 2>/dev/null \
     | rg ' ssh-ed25519 ' \
     | ssh-keygen -lf -
   ```
   Then remove the temporary USB and factory entries and reconnect:
   ```bash
   ssh-keygen -R <ip>
   ssh-keygen -R spark-0N.local
   ssh spark-0N.local
   ```

Successful remote builds publish their complete input and output closures to
the personal cache automatically. The installer uses that cache, so later
nodes substitute the kernel and drivers without a manual upload step. A
`nixpkgs` update produces new store paths; the first remote build publishes
their replacements.

## Deploy changes

```bash
just deploy spark-01
just spark-deploy-all
```

`nh os switch` builds through the configured remote builders, copies the result
to the target, and activates over SSH. Rollback is a reboot into the previous
systemd-boot generation. For risky networking changes, activate without setting
the boot default first:

```bash
nixos-rebuild test --flake .#spark-01 --target-host angel@spark-01.local --use-remote-sudo
```

## Secrets

- `spark-01` receives controller-only secrets from
  `machines/nixos/spark/secrets/controller.yaml`.
- Every Spark receives shared cluster secrets from
  `machines/nixos/spark/secrets/shared.yaml`.
- Generate and register each permanent host identity before installation, then
  run `just sops-update-keys` so its assigned files target the new identity.
- Do not add the Sparks to the repository-wide secret recipient rule.

## Laguna S 2.1 with vLLM

`spark-01` builds a pinned CUDA 13, vLLM 0.25.1, and FlashInfer container.
The image build is declarative, but the model is kept out of the Nix store and
downloaded manually. Follow the image build with:

```bash
ssh spark-01.local journalctl -fu vllm-laguna-image
```

Download the pinned target and DFlash draft revisions into their configured
paths:

```bash
ssh spark-01.local hf download \
  poolside/Laguna-S-2.1-NVFP4 \
  --revision b482b5d57fda6e4e562a652869bde24ba2a57c92 \
  --local-dir /srv/models/poolside-Laguna-S-2.1-NVFP4

ssh spark-01.local hf download \
  poolside/Laguna-S-2.1-DFlash-NVFP4 \
  --revision 723794750422b3efbf3a7b3af76dffb4ba035943 \
  --local-dir /srv/models/poolside-Laguna-S-2.1-DFlash-NVFP4
```

Start the server manually for its first run:

```bash
ssh spark-01.local sudo systemctl start podman-vllm-laguna
ssh spark-01.local journalctl -fu podman-vllm-laguna
```

The first start can take about 15 minutes. After validating it, set
`services.vllm-laguna.autoStart = true` in `configuration.nix`.

## Open WebUI

Open WebUI runs on the controller and uses the local vLLM server as its only
model provider. It binds to loopback during initial setup so an arbitrary LAN
client cannot claim the first account, which Open WebUI promotes to admin.

Deploy it, then keep this tunnel running while using the UI:

```bash
just deploy spark-01
ssh -N -L 8080:127.0.0.1:8080 spark-01.local
```

Open <http://127.0.0.1:8080>, create the admin account, and disable new account
registration in the admin settings. Application data is persisted in
`/var/lib/open-webui`; the model weights remain in `/srv/models` and are served
through vLLM.
