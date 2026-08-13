# Reinstall NixOS

Every enrolled NixOS machine needs its Clan machine Age identity before first
boot:

- `/var/lib/sops-nix/key.txt` is the Clan machine Age identity. It decrypts
  Clan vars, including the SSH host key used by `sshd`.

Portal and Sisyphus additionally need the retained legacy identity at
`/etc/ssh/ssh_host_ed25519_key` because direct sops-nix files still use its
derived Age recipient. The default `scripts/stage-install-secrets.sh` mode
stages and cross-checks both identities for those hosts.

Sparks use the helper's explicit `--clan-only` mode. It stages only
`/var/lib/sops-nix/key.txt`, verifies that this identity decrypts the tracked
Clan `openssh` key pair, and never creates `/etc/ssh` host keys. Spark
coordination uses a separate Clan-managed key.

Use the repository entrypoints rather than running Disko or `nixos-install`
directly. Commit and back up every identity, recipient, and var file first.
Confirm current backups and the target disk identifiers before accepting an
erase prompt.

```sh
just provision portal root@<installer-ip>
just spark-install spark-04
```

The supported paths are:

- `just provision portal root@<installer-ip>` erases Portal's disk. It also
  loses `/var/lib/pangolin` unless that state is restored separately.
- `just provision sisyphus root@<installer-ip>` recreates every filesystem in
  Sisyphus's Disko graph, including local data.
- `just spark-install spark-0N` uses the Spark-specific USB installer path,
  stages only the Clan machine identity, and erases that node's NVMe.
- Kiwi reinstall is intentionally not automated. Its current Disko graph
  includes every `storagepool` disk and would erase `/srv/share` and
  `/srv/backups`. Stop and design a reviewed OS-disk-only recovery before
  attempting it.

The Spark installer only supports the four nodes already enrolled in Clan.
Adding another node is a separate enrollment procedure and is not covered by
this reinstall path. Never run the `openssh` generator for a replacement: a
different key would change the server fingerprint, invalidate pinned known
hosts, and break the cluster topology contract. Run `clan vars check <node>`
before erasing an enrolled node.

After reinstalling Portal or Sisyphus, keep an installer or console recovery
path open and run:

```sh
host=portal
target=portal

ssh-keygen -lf "secrets/host-keys/$host.pub"
ssh-keyscan -T 5 -t ed25519 "$target" 2>/dev/null | ssh-keygen -lf -

ssh "$target" 'sudo bash -s' <<'REMOTE'
set -euo pipefail
legacy=/etc/ssh/ssh_host_ed25519_key
runtime=/run/secrets/vars/openssh/ssh.id_ed25519

test -s "$legacy"
test -s "$runtime"
cmp -s "$legacy" "$runtime"
test "$(stat -c %a "$legacy")" = 600
test "$(stat -c %a "$runtime")" = 400
systemctl is-active --quiet sshd.service
test -z "$(systemctl --failed --no-legend --plain)"
REMOTE
```

The two printed fingerprints must match. Keep the retained `/etc/ssh` identity
and escrow files until that host's legacy SOPS recipients have migrated.

After reinstalling a Spark, verify its Clan-only identity instead:

```sh
host=spark-04
target=spark-04

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
test "$(stat -c %a "$machine")" = 600
test "$(stat -c %a "$runtime")" = 400
test ! -e /etc/ssh/ssh_host_ed25519_key
test ! -e /etc/ssh/ssh_host_ed25519_key.pub
systemctl is-active --quiet sshd.service
test -z "$(systemctl --failed --no-legend --plain)"
REMOTE
```

Open a second strict SSH connection before closing the recovery session, then
verify the host's workload-specific services and data.
