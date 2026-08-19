#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage:
  $0 <portal|sisyphus> <ssh-target>
  $0 <spark-node>
EOF
  exit 2
}

(($# >= 1 && $# <= 2)) || usage
host=$1
target=${2:-}
repo_root=$(git rev-parse --show-toplevel)
install_options=(
  --flake "$repo_root"
  --build-on remote
  --yes
)

clan() {
  nix run "$repo_root#clan" -- "$@"
}

case $host in
portal | sisyphus)
  [[ -n $target ]] || usage
  ;;
kiwi)
  echo "Kiwi installation is intentionally blocked: its Disko graph includes the storage pool." >&2
  echo "See docs/operations/install-nixos.md." >&2
  exit 1
  ;;
spark-*)
  [[ -z $target ]] || usage
  if [[ ! $host =~ ^spark-[0-9]+$ ]]; then
    echo "Invalid Spark node name: $host" >&2
    exit 1
  fi
  ip=$(nix eval --raw \
    "$repo_root#lib.sparkCluster.nodes.$host.managementAddress" 2>/dev/null) || {
    echo "Unknown Spark node: $host" >&2
    exit 1
  }
  target="root@$ip"
  install_options+=(
    --phases "disko,install,reboot"
    --option extra-substituters https://unclegravity-nix.cachix.org
    --option extra-trusted-public-keys unclegravity-nix.cachix.org-1:fnXTPHMhvKwMrqyU/z00iyf8SkUuK0YP2PpCYb1t3nI=
  )
  ;;
*)
  echo "Installation is unsupported for '$host'." >&2
  exit 1
  ;;
esac

# Installs must consume enrolled identities, never generate replacements.
clan vars check "$host" \
  --flake "$repo_root"

# Force NixOS assertions and full configuration evaluation before erasing.
nix eval --raw \
  "$repo_root#nixosConfigurations.$host.config.system.build.toplevel.drvPath" \
  >/dev/null

echo "This will ERASE the disk on $target and install '$host' from this flake."
echo "Clan will stage the existing vars and machine identity."
echo "No /etc/ssh host identity will be installed."
read -r -p "Type $host to continue: " confirmation
if [[ $confirmation != "$host" ]]; then
  echo "Confirmation did not match; aborting." >&2
  exit 1
fi

clan machines install "$host" \
  --target-host "$target" \
  "${install_options[@]}"
