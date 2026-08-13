#!/usr/bin/env bash
set -euo pipefail

set +x
umask 077

usage() {
  echo "Usage: $0 <host> <staging-root>" >&2
  exit 2
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

validate_host() {
  local host=$1
  [[ $host =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] ||
    die "invalid host name: $host"
}

configure_operator_identity() {
  local local_identity

  if [[ -n ${SOPS_AGE_KEY:-} ]]; then
    unset SOPS_AGE_KEY_CMD SOPS_AGE_KEY_FILE
    return
  fi

  if [[ -n ${SOPS_AGE_KEY_FILE:-} ]]; then
    [[ -f $SOPS_AGE_KEY_FILE && ! -L $SOPS_AGE_KEY_FILE && -r $SOPS_AGE_KEY_FILE ]] ||
      die "operator identity file is not a readable regular file: $SOPS_AGE_KEY_FILE"
    SOPS_AGE_KEY_FILE=$(cd -- "$(dirname -- "$SOPS_AGE_KEY_FILE")" && pwd -P)/$(basename -- "$SOPS_AGE_KEY_FILE")
    export SOPS_AGE_KEY_FILE
    unset SOPS_AGE_KEY_CMD
    return
  fi

  if [[ -n ${XDG_CONFIG_HOME:-} ]]; then
    local_identity=$XDG_CONFIG_HOME/sops/age/keys.txt
  elif [[ ${OSTYPE:-} == darwin* ]]; then
    local_identity=$HOME/Library/Application\ Support/sops/age/keys.txt
  else
    local_identity=$HOME/.config/sops/age/keys.txt
  fi

  if [[ -f $local_identity && -r $local_identity ]]; then
    unset SOPS_AGE_KEY SOPS_AGE_KEY_CMD
    export SOPS_AGE_KEY_FILE=$local_identity
    return
  fi

  die "set SOPS_AGE_KEY, SOPS_AGE_KEY_FILE, or install the operator identity at '$local_identity'"
}

require_regular_file() {
  local path=$1
  [[ -f $path && ! -L $path && -s $path ]] ||
    die "expected a nonempty regular file: $path"
}

file_mode() {
  local path=$1
  local mode

  if mode=$(stat -c "%a" "$path" 2>/dev/null); then
    printf "%s\n" "$mode"
    return
  fi
  if mode=$(stat -f "%Lp" "$path" 2>/dev/null); then
    printf "%s\n" "$mode"
    return
  fi
  die "cannot determine file mode: $path"
}

(($# == 2)) || usage
host=$1
root=$2

validate_host "$host"
[[ -d $root ]] || die "staging root does not exist: $root"
root=$(cd -- "$root" && pwd -P)
[[ $root != "/" ]] || die "refusing to stage install secrets into the live root"

for path in "$root/etc" "$root/etc/ssh" "$root/var" "$root/var/lib" "$root/var/lib/sops-nix"; do
  [[ ! -L $path ]] || die "refusing to follow a symlink in the staging tree: $path"
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(git -C "$script_dir/.." rev-parse --show-toplevel)
machine_metadata=$repo_root/sops/machines/$host/key.json
clan_private=$repo_root/vars/per-machine/$host/openssh/ssh.id_ed25519/secret
clan_public=$repo_root/vars/per-machine/$host/openssh/ssh.id_ed25519.pub/value
escrow_public=$repo_root/secrets/host-keys/$host.pub
scratch_dir=$(mktemp -d "${TMPDIR:-/tmp}/install-secrets.XXXXXX")
published_files=()
published_dirs=()
publish_complete=false

cleanup() {
  local status=$?
  local path

  trap - EXIT
  set +e
  if [[ $publish_complete != true ]]; then
    for path in "${published_files[@]}"; do
      [[ ! -e $path ]] || unlink "$path"
    done
    for path in "${published_dirs[@]}"; do
      [[ ! -e $path ]] || rm -rf -- "$path"
    done
  fi
  rm -rf -- "$scratch_dir"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

machine_dir=$scratch_dir/var/lib/sops-nix
machine_key=$machine_dir/key.txt
ssh_dir=$scratch_dir/etc/ssh
legacy_private=$ssh_dir/ssh_host_ed25519_key
legacy_public=$ssh_dir/ssh_host_ed25519_key.pub
target_machine_dir=$root/var/lib/sops-nix
target_ssh_dir=$root/etc/ssh

for command in age-keygen chmod cmp cp git install jq mktemp nix rm sops ssh-keygen stat unlink; do
  require_command "$command"
done

for path in "$machine_metadata" "$clan_private" "$clan_public" "$escrow_public"; do
  require_regular_file "$path"
done

if [[ -e $target_machine_dir || -L $target_machine_dir ]]; then
  die "refusing to overwrite staged Clan identity directory: $target_machine_dir"
fi

for path in \
  "$target_ssh_dir/ssh_host_ed25519_key" \
  "$target_ssh_dir/ssh_host_ed25519_key.pub"; do
  if [[ -e $path || -L $path ]]; then
    die "refusing to overwrite staged identity: $path"
  fi
done

configure_operator_identity

clan() {
  CLAN_DIR="$repo_root" NIX_CONFIG="builders =" \
    nix run --builders "" "$repo_root#clan" -- "$@"
}

clan vars check "$host"
install -d -m 0700 "$machine_dir"
clan vars upload "$host" --directory "$machine_dir"
chmod 0700 "$machine_dir"
chmod 0600 "$machine_key"

(
  cd "$repo_root"
  "$script_dir/host-key.sh" stage "$host" "$scratch_dir"
)

require_regular_file "$machine_key"
require_regular_file "$legacy_private"
require_regular_file "$legacy_public"

expected_recipient=$(jq -er '
  if type == "array"
    and length == 1
    and .[0].type == "age"
    and (.[0].publickey | type == "string")
  then .[0].publickey
  else error("expected exactly one Age machine recipient")
  end
' "$machine_metadata") || die "invalid Clan machine key metadata for '$host'"
actual_recipient=$(age-keygen -y "$machine_key") ||
  die "staged Clan machine identity is invalid"
[[ $actual_recipient == "$expected_recipient" ]] ||
  die "staged Clan machine identity does not match '$host'"

cmp -s "$legacy_public" "$escrow_public" ||
  die "staged SSH public key does not match its escrowed value"
cmp -s "$legacy_public" "$clan_public" ||
  die "legacy and Clan SSH public keys differ"

if ! env \
  -u SOPS_AGE_KEY \
  -u SOPS_AGE_KEY_CMD \
  SOPS_AGE_KEY_FILE="$machine_key" \
  sops decrypt \
  --extract '["data"]' \
  --output-type binary \
  "$clan_private" | cmp -s - "$legacy_private"; then
  die "staged Clan machine identity does not decrypt the retained SSH key"
fi

[[ $(file_mode "$machine_dir") == 700 ]] ||
  die "unexpected mode on Clan machine identity directory"
[[ $(file_mode "$machine_key") == 600 ]] ||
  die "unexpected mode on Clan machine identity"
[[ $(file_mode "$legacy_private") == 600 ]] ||
  die "unexpected mode on retained SSH private key"
[[ $(file_mode "$legacy_public") == 644 ]] ||
  die "unexpected mode on retained SSH public key"

install -d -m 0755 "$(dirname -- "$target_machine_dir")"
install -d -m 0755 "$target_ssh_dir"
published_dirs+=("$target_machine_dir")
cp -a "$machine_dir" "$target_machine_dir"
published_files+=("$target_ssh_dir/ssh_host_ed25519_key")
install -m 0600 "$legacy_private" "$target_ssh_dir/ssh_host_ed25519_key"
published_files+=("$target_ssh_dir/ssh_host_ed25519_key.pub")
install -m 0644 "$legacy_public" "$target_ssh_dir/ssh_host_ed25519_key.pub"
publish_complete=true

echo "Staged and verified both install identities for '$host' under '$root'."
