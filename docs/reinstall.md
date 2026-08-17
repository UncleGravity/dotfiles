# Reinstall NixOS

Every enrolled NixOS machine needs its Clan machine Age identity before first
boot:

- `/var/lib/sops-nix/key.txt` decrypts the machine's Clan vars, including the
  SSH host key used by `sshd`.
- `scripts/stage-install-secrets.sh` verifies the machine identity against
  `sops/machines/<host>/key.json`, proves that it decrypts the tracked Clan
  `openssh` key pair, and stages only that identity.
- The installed system uses
  `/run/secrets/vars/openssh/ssh.id_ed25519`. The installer never stages an
  `/etc/ssh` host identity.

Use the repository entrypoints rather than running Disko or `nixos-install`
directly. Commit and back up every identity, recipient, and var file first.
Confirm current backups and the target disk identifiers before accepting an
erase prompt.

```sh
just provision portal root@<installer-ip>
just spark-install spark-04
```

The supported paths are:

- `just provision portal root@<installer-ip>` stages the Clan identity and
  erases Portal's disk. It also loses `/var/lib/pangolin` unless that state is
  restored separately.
- `just provision sisyphus root@<installer-ip>` recreates every filesystem in
  Sisyphus's Disko graph, including local data.
- `just spark-install spark-0N` uses the Spark-specific USB installer path and
  erases that node's NVMe.
- Kiwi reinstall is intentionally not automated. Its current Disko graph
  includes every `storagepool` disk and would erase `/srv/share` and
  `/srv/backups`. Stop and design a reviewed OS-disk-only recovery before
  attempting it.

Both installers fail before the erase prompt unless the evaluated machine uses
empty `sops.age.sshKeyPaths` and `sops.gnupg.sshKeyPaths` lists and exactly one
Ed25519 host key at the Clan runtime path. The Spark installer supports only the
four existing nodes; adding another node is a separate enrollment procedure.

Never regenerate an enrolled machine's `openssh` var during reinstall. A new
key changes its server fingerprint and invalidates pinned known hosts. Run
`nix run --builders "" .#clan -- vars check <host>` before erasing a machine.

After reinstalling any supported host, keep the installer or console recovery
path open and run:

```sh
host=portal
target=portal

ssh-keygen -lf "vars/per-machine/$host/openssh/ssh.id_ed25519.pub/value"
ssh-keyscan -T 5 -t ed25519 "$target" 2>/dev/null \
  | rg ' ssh-ed25519 ' \
  | ssh-keygen -lf -

ssh "$target" 'sudo bash -s' <<'REMOTE'
set -euo pipefail
machine=/var/lib/sops-nix/key.txt
runtime=/run/secrets/vars/openssh/ssh.id_ed25519

test -s "$machine"
test -s "$runtime"
test "$(stat -c %a "$machine")" = 400
test "$(stat -c %a "$runtime")" = 400
test ! -e /etc/ssh/ssh_host_ed25519_key
test ! -e /etc/ssh/ssh_host_ed25519_key.pub
test "$(sshd -T | awk 'tolower($1) == "hostkey" { print $2 }')" \
  = "$runtime"
systemctl is-active --quiet sshd.service
test -z "$(systemctl --failed --no-legend --plain)"
REMOTE
```

The two printed fingerprints must match. Open a second strict SSH connection
before closing the recovery session, then verify the host's workload-specific
services and data.
