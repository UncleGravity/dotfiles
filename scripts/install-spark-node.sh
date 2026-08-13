#!/usr/bin/env bash
set -euo pipefail

umask 077

usage() {
  echo "Usage: $0 <spark-01|spark-02|spark-03|spark-04>" >&2
  echo "Run against a node booted into the NixOS USB installer." >&2
  echo "See docs/spark/install-node.md." >&2
  exit 2
}

(($# == 1)) || usage
node=$1
repo_root=$(git rev-parse --show-toplevel)
cache_url=https://unclegravity-nix.cachix.org
cache_key=unclegravity-nix.cachix.org-1:fnXTPHMhvKwMrqyU/z00iyf8SkUuK0YP2PpCYb1t3nI=

ip=$(nix eval --builders "" --raw \
  "$repo_root#lib.sparkCluster.nodes.$node.managementAddress" 2>/dev/null) || {
  echo "Unknown Spark node: $node" >&2
  exit 1
}

identity_contract=$(nix eval --builders "" --raw \
  "$repo_root#nixosConfigurations.$node.config" \
  --apply 'config:
    let
      hostKeys = config.services.openssh.hostKeys;
    in
      if config.sops.age.sshKeyPaths == []
        && builtins.length hostKeys == 1
        && (builtins.head hostKeys).path == "/run/secrets/vars/openssh/ssh.id_ed25519"
        && (builtins.head hostKeys).type == "ed25519"
      then "clan-only"
      else throw "Spark install requires Clan-only SOPS and SSH host identity configuration"')
[[ $identity_contract == "clan-only" ]] || {
  echo "Spark identity configuration is not Clan-only: $node" >&2
  exit 1
}

echo "This will ERASE the NVMe on $node ($ip) and install NixOS."
echo "Only the Clan machine identity will be staged; no legacy /etc/ssh identity will be installed."
read -r -p "Type $node to continue: " confirmation
if [[ $confirmation != "$node" ]]; then
  echo "Confirmation did not match; aborting." >&2
  exit 1
fi

extra_files=$(mktemp -d)
trap 'rm -rf -- "$extra_files"' EXIT
"$repo_root/scripts/stage-install-secrets.sh" --clan-only "$node" "$extra_files"

nixos-anywhere --flake "$repo_root#$node" --target-host "root@$ip" \
  --extra-files "$extra_files" \
  --build-on remote \
  --option builders "" \
  --option extra-substituters "$cache_url" \
  --option extra-trusted-public-keys "$cache_key" \
  --phases disko,install,reboot
