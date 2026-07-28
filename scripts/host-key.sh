#!/usr/bin/env bash
set -euo pipefail

# Generate a stable SSH host identity for use by provision.sh.

usage() {
	echo "Usage: $0 <hostname>" >&2
	exit 2
}

(($# == 1)) || usage
host=$1
repo_root=$(git rev-parse --show-toplevel)
host_key_dir=$repo_root/secrets/host-keys
public_key=$host_key_dir/$host.pub
encrypted_key=$host_key_dir/$host.key.sops

if [[ -e $public_key || -e $encrypted_key ]]; then
	echo "Host key for '$host' already exists in $host_key_dir; refusing to overwrite." >&2
	echo "Delete both files manually if you really want to rotate its identity." >&2
	exit 1
fi

mkdir -p "$host_key_dir"
temp_dir=$(mktemp -d)
published=false
cleanup() {
	rm -rf "$temp_dir"
	if [[ $published == false ]]; then
		rm -f "$public_key" "$encrypted_key"
	fi
}
trap cleanup EXIT

ssh-keygen -q -t ed25519 -N "" -C "$host" -f "$temp_dir/key"

# Apply the repository SOPS rule without writing the private key into the repo.
(cd "$repo_root" && sops encrypt --filename-override "secrets/host-keys/$host.key.sops" \
	--input-type binary "$temp_dir/key" >"$temp_dir/key.sops")

age_key=$(ssh-to-age <"$temp_dir/key.pub")
install -m 644 "$temp_dir/key.sops" "$encrypted_key"
install -m 644 "$temp_dir/key.pub" "$public_key"
published=true

echo "Host key for '$host' generated:"
echo "  public:    ${public_key#"$repo_root"/}"
echo "  encrypted: ${encrypted_key#"$repo_root"/}"
echo ""
echo "Next steps:"
echo "  1. Add to .sops.yaml under &hosts:   - &$host $age_key"
echo "  2. Add a creation rule for machines/nixos/$host/ (above the all-machines rule)."
echo "     (only if you add $host to a rule for an EXISTING file, e.g. the shared"
echo "     secrets.yaml: re-encrypt it with 'sops updatekeys <file>')"
echo "  3. Provision with: just provision $host root@<ip>"
