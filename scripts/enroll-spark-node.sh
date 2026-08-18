#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <spark-node>" >&2
  exit 2
}

(($# == 1)) || usage
node=$1

if [[ ! $node =~ ^spark-[0-9]+$ ]]; then
  echo "Invalid Spark node name: $node" >&2
  exit 1
fi

repo_root=$(git rev-parse --show-toplevel)
machine_module="machines/$node/configuration.nix"

if ! git -C "$repo_root" ls-files --error-unmatch "$machine_module" >/dev/null 2>&1; then
  echo "Stage $machine_module before enrollment so Nix can evaluate the machine." >&2
  exit 1
fi

if ! nix eval --builders "" --raw \
  "$repo_root#lib.sparkCluster.nodes.$node.managementAddress" \
  >/dev/null 2>&1; then
  echo "Spark inventory does not contain '$node'." >&2
  exit 1
fi

if [[ -e $repo_root/sops/machines/$node/key.json ||
  -e $repo_root/sops/secrets/${node}-age.key ||
  -e $repo_root/vars/per-machine/$node ]]; then
  echo "Clan identity state already exists for '$node'; refusing to enroll it again." >&2
  echo "Use 'nix run .#clan -- vars check $node' to validate an existing enrollment." >&2
  exit 1
fi

clan() {
  CLAN_NO_COMMIT=1 nix run --builders "" "$repo_root#clan" -- "$@"
}

stage_generated_state() {
  local entry path

  while IFS= read -r -d '' entry; do
    path=${entry:3}
    case $path in
    "sops/machines/$node/"* | "sops/secrets/$node-age.key/"* | "vars/per-machine/$node/"* | vars/*/machines/"$node")
      git -C "$repo_root" add -- "$path"
      ;;
    esac
  done < <(git -C "$repo_root" status --porcelain=v1 -z --untracked-files=all)
}

# Generate the host identity first because the Spark topology publishes its
# public key. Clan creates the machine Age identity as part of this operation.
clan vars generate "$node" \
  --generator openssh \
  --flake "$repo_root" \
  --option builders ""
stage_generated_state

clan vars generate "$node" \
  --flake "$repo_root" \
  --option builders ""
stage_generated_state

clan vars check "$node" \
  --flake "$repo_root" \
  --option builders ""

nix eval --builders "" --raw \
  "$repo_root#nixosConfigurations.$node.config.system.build.toplevel.drvPath" \
  >/dev/null

cat <<EOF
Enrolled '$node' without installing it.

Review the staged generated files, including:
  sops/machines/$node/
  sops/secrets/$node-age.key/
  vars/per-machine/$node/
  shared-var machine recipient links for $node

Commit that enrollment, then boot the NixOS USB installer and run:
  just spark-install $node
EOF
