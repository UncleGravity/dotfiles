#!/usr/bin/env bash
set -euo pipefail

umask 077

# Install NixOS with its Clan machine identity; erases the target disk.

usage() {
  echo "Usage: $0 <hostname> <ssh-target>   e.g. $0 portal root@1.2.3.4" >&2
  exit 2
}

(($# == 2)) || usage
host=$1
target=$2
repo_root=$(git rev-parse --show-toplevel)

case $host in
portal | sisyphus) ;;
kiwi)
  echo "Kiwi reinstall is intentionally not automated: its Disko graph includes the storage pool." >&2
  echo "Stop and design a reviewed OS-disk-only recovery; see docs/reinstall.md." >&2
  exit 1
  ;;
spark-01 | spark-02 | spark-03 | spark-04)
  echo "Use 'just spark-install $host' for DGX Spark hardware." >&2
  exit 1
  ;;
*)
  echo "Generic provisioning is unsupported for '$host'." >&2
  exit 1
  ;;
esac

identity_contract=$(nix eval --builders "" --raw \
  "$repo_root#nixosConfigurations.$host.config" \
  --apply 'config:
    let
      hostKeys = config.services.openssh.hostKeys;
    in
      if config.sops.age.keyFile == "/var/lib/sops-nix/key.txt"
        && config.sops.age.sshKeyPaths == []
        && builtins.length hostKeys == 1
        && (builtins.head hostKeys).path == "/run/secrets/vars/openssh/ssh.id_ed25519"
        && (builtins.head hostKeys).type == "ed25519"
      then "clan-only"
      else throw "Provisioning requires Clan-only SOPS and SSH host identity configuration"')
[[ $identity_contract == "clan-only" ]] || {
  echo "Identity configuration is not Clan-only: $host" >&2
  exit 1
}

echo "This will ERASE the disk on $target and install '$host' from this flake."
echo "Only the Clan machine identity will be staged; no /etc/ssh host identity will be installed."
read -r -p "Type $host to continue: " confirmation
if [[ $confirmation != "$host" ]]; then
  echo "Confirmation did not match; aborting." >&2
  exit 1
fi

extra_files=$(mktemp -d)
trap 'rm -rf "$extra_files"' EXIT
"$repo_root/scripts/stage-install-secrets.sh" "$host" "$extra_files"

nixos-anywhere --flake "$repo_root#$host" \
  --target-host "$target" \
  --extra-files "$extra_files" \
  --build-on remote \
  --option builders ""
