#!/usr/bin/env bash
set -euo pipefail

umask 077

usage() {
	cat >&2 <<'EOF'
Usage:
  host-key.sh create <host>
  host-key.sh import <host> <private-key|->
  host-key.sh check [host]
  host-key.sh stage <host> <root> [--force]

Commands:
  create  Generate and escrow a new ED25519 host identity.
  import  Escrow an existing ED25519 private key. Completes a matching public-only bundle.
          Use - to read from stdin.
  check   Verify key pairs, Age recipients, and the SOPS recipient policy.
  stage   Install a checked key pair under <root>/etc/ssh for provisioning.

Rotation is intentionally not implicit. It requires a coordinated SOPS and
known_hosts transition.
EOF
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

repo_root=$(git rev-parse --show-toplevel)
host_key_dir=$repo_root/secrets/host-keys
sops_config=$repo_root/.sops.yaml
scratch_dir=

cleanup() {
	if [[ -n $scratch_dir ]]; then
		rm -rf -- "$scratch_dir"
	fi
}
trap cleanup EXIT

ensure_scratch_dir() {
	if [[ -z $scratch_dir ]]; then
		scratch_dir=$(mktemp -d "${TMPDIR:-/tmp}/host-key.XXXXXX")
	fi
}

set_bundle_paths() {
	local host=$1
	public_key=$host_key_dir/$host.pub
	encrypted_key=$host_key_dir/$host.key.sops
	relative_encrypted_key=secrets/host-keys/$host.key.sops
}

ensure_bundle_absent() {
	local host=$1
	set_bundle_paths "$host"

	if [[ -e $public_key || -L $public_key || -e $encrypted_key || -L $encrypted_key ]]; then
		die "host identity for '$host' already exists; refusing to overwrite it"
	fi
}

validate_key_pair() {
	local private_key=$1
	local public_key_file=$2
	local key_type
	local key_data
	local derived_key_type
	local derived_key_data
	local unused
	local derived_public_key

	IFS=" " read -r key_type key_data unused <"$public_key_file" ||
		die "cannot read public key: $public_key_file"
	[[ $key_type == "ssh-ed25519" ]] ||
		die "host keys must be ED25519, got '$key_type'"

	derived_public_key=$(ssh-keygen -y -f "$private_key" 2>/dev/null) ||
		die "cannot derive a public key from: $private_key"
	IFS=" " read -r derived_key_type derived_key_data unused <<<"$derived_public_key"
	[[ $derived_key_type == "$key_type" && $derived_key_data == "$key_data" ]] ||
		die "private and public host keys do not match"
}

configured_host_recipient() {
	local host=$1
	local marker
	local anchor
	local recipient
	local unused
	local found=

	while IFS=" " read -r marker anchor recipient unused; do
		if [[ $marker == "-" && $anchor == "&$host" ]]; then
			[[ -z $found ]] || die "duplicate SOPS anchor found for '$host'"
			found=$recipient
		fi
	done <"$sops_config"

	[[ -n $found ]] || return 1
	printf "%s\n" "$found"
}

policy_recipients() {
	local relative_path=$1

	(
		cd "$repo_root"
		SOPS_RELATIVE_PATH=$relative_path nu -c '
			let path = $env.SOPS_RELATIVE_PATH
			open .sops.yaml
			| get creation_rules
			| where {|rule|
				let pattern = ($rule.path_regex? | default ".*")
				$path =~ $pattern
			}
			| first
			| get age
			| sort
			| str join (char nl)
		'
	)
}

encrypted_recipients() {
	local encrypted_key_file=$1

	SOPS_FILE=$encrypted_key_file nu -c '
		open --raw $env.SOPS_FILE
		| from json
		| get sops.age.recipient
		| sort
		| str join (char nl)
	'
}

validate_recipient_policy() {
	local encrypted_key_file=$1
	local relative_path=$2
	local expected
	local actual

	expected=$(policy_recipients "$relative_path") ||
		die "cannot determine SOPS policy for: $relative_path"
	actual=$(encrypted_recipients "$encrypted_key_file") ||
		die "cannot read SOPS recipients from: $encrypted_key_file"

	if [[ $actual != "$expected" ]]; then
		printf "error: SOPS recipients do not match policy for %s\n" "$relative_path" >&2
		printf "expected:\n%s\nactual:\n%s\n" "$expected" "$actual" >&2
		exit 1
	fi
}

encrypt_private_key() {
	local host=$1
	local private_key_file=$2
	local output_file=$3
	local relative_path=secrets/host-keys/$host.key.sops

	(
		cd "$repo_root"
		sops --config "$sops_config" encrypt \
			--filename-override "$relative_path" \
			--input-type binary \
			"$private_key_file"
	) >"$output_file"

	[[ $(sops filestatus "$output_file") == '{"encrypted":true}' ]] ||
		die "SOPS did not produce an encrypted host key"
	validate_recipient_policy "$output_file" "$relative_path"
}

publish_bundle() {
	local host=$1
	local private_key_file=$2
	local public_key_file=$3
	local encrypted_output=$scratch_dir/$host.key.sops

	ensure_bundle_absent "$host"
	validate_key_pair "$private_key_file" "$public_key_file"
	encrypt_private_key "$host" "$private_key_file" "$encrypted_output"

	mkdir -p "$host_key_dir"
	install -m 0644 "$encrypted_output" "$encrypted_key"
	if ! install -m 0644 "$public_key_file" "$public_key"; then
		rm -f -- "$encrypted_key"
		die "failed to publish public host key"
	fi
}

publish_import() {
	local host=$1
	local private_key_file=$2
	local derived_public_key_file=$3
	local encrypted_output=$scratch_dir/$host.key.sops

	set_bundle_paths "$host"
	if [[ -e $encrypted_key || -L $encrypted_key ]]; then
		die "encrypted host key for '$host' already exists; refusing to overwrite it"
	fi

	if [[ -e $public_key || -L $public_key ]]; then
		[[ -f $public_key && ! -L $public_key ]] ||
			die "public host key for '$host' is not a regular file"
		validate_key_pair "$private_key_file" "$public_key"
		encrypt_private_key "$host" "$private_key_file" "$encrypted_output"
		[[ ! -e $encrypted_key && ! -L $encrypted_key ]] ||
			die "encrypted host key for '$host' appeared during import; refusing to overwrite it"
		install -m 0644 "$encrypted_output" "$encrypted_key"
		return
	fi

	publish_bundle "$host" "$private_key_file" "$derived_public_key_file"
}

print_enrollment_steps() {
	local host=$1
	local recipient
	local configured_recipient

	set_bundle_paths "$host"
	recipient=$(ssh-to-age <"$public_key")

	echo "Host identity for '$host' escrowed:"
	echo "  public:    ${public_key#"$repo_root"/}"
	echo "  encrypted: ${encrypted_key#"$repo_root"/}"
	echo "  host Age identity: $recipient"

	if configured_recipient=$(configured_host_recipient "$host"); then
		if [[ $configured_recipient == "$recipient" ]]; then
			echo
			echo "SOPS anchor '&$host' already matches."
			echo "Verify with: just host-key check $host"
			return
		fi
		echo
		echo "Next steps:"
		echo "  1. Update '&$host' in .sops.yaml to: $recipient"
	else
		echo
		echo "Next steps:"
		echo "  1. Add '- &$host $recipient' to the recipient list in .sops.yaml."
	fi

	echo "  2. Add or update the host's creation rule."
	echo "  3. Run: just sops-update-keys"
	echo "  4. Run: just host-key check $host"
}

create_host() {
	local host=$1
	local private_key_file

	validate_host "$host"
	ensure_scratch_dir
	private_key_file=$scratch_dir/$host.key

	ssh-keygen -q -t ed25519 -N "" -C "$host" -f "$private_key_file"
	publish_bundle "$host" "$private_key_file" "$private_key_file.pub"
	print_enrollment_steps "$host"
}

import_host() {
	local host=$1
	local source=$2
	local private_key_file
	local public_key_file
	local derived_public_key
	local derived_key_type
	local derived_key_data
	local unused

	validate_host "$host"
	set_bundle_paths "$host"
	if [[ -e $encrypted_key || -L $encrypted_key ]]; then
		die "encrypted host key for '$host' already exists; refusing to overwrite it"
	fi
	ensure_scratch_dir
	private_key_file=$scratch_dir/$host.key
	public_key_file=$private_key_file.pub

	if [[ $source == "-" ]]; then
		cat >"$private_key_file"
	else
		[[ -f $source ]] || die "private key not found: $source"
		install -m 0600 "$source" "$private_key_file"
	fi
	chmod 0600 "$private_key_file"

	derived_public_key=$(ssh-keygen -y -f "$private_key_file" 2>/dev/null) ||
		die "cannot derive a public key from imported key"
	IFS=" " read -r derived_key_type derived_key_data unused <<<"$derived_public_key"
	printf "%s %s %s\n" "$derived_key_type" "$derived_key_data" "$host" >"$public_key_file"

	publish_import "$host" "$private_key_file" "$public_key_file"
	print_enrollment_steps "$host"
}

check_host() {
	local host=$1
	local private_key_file
	local derived_recipient
	local configured_recipient
	local fingerprint

	validate_host "$host"
	set_bundle_paths "$host"
	[[ -f $encrypted_key ]] || die "encrypted host key not found: $encrypted_key"
	[[ -f $public_key ]] || die "public host key not found: $public_key"

	validate_recipient_policy "$encrypted_key" "$relative_encrypted_key"
	ensure_scratch_dir
	private_key_file=$scratch_dir/$host.check.key
	sops decrypt --output-type binary "$encrypted_key" >"$private_key_file"
	chmod 0600 "$private_key_file"
	validate_key_pair "$private_key_file" "$public_key"

	derived_recipient=$(ssh-to-age <"$public_key")
	configured_recipient=$(configured_host_recipient "$host") ||
		die "no SOPS recipient anchor found for '$host'"
	[[ $derived_recipient == "$configured_recipient" ]] ||
		die "public key recipient does not match the '&$host' SOPS anchor"

	fingerprint=$(ssh-keygen -lf "$public_key")
	echo "ok: $host: $fingerprint"
}

check_all_hosts() {
	local encrypted_keys
	local public_keys
	local file
	local host

	shopt -s nullglob
	encrypted_keys=("$host_key_dir"/*.key.sops)
	public_keys=("$host_key_dir"/*.pub)
	((${#encrypted_keys[@]} > 0)) || die "no escrowed host identities found"

	for file in "${encrypted_keys[@]}"; do
		host=${file##*/}
		host=${host%.key.sops}
		check_host "$host"
	done

	for file in "${public_keys[@]}"; do
		host=${file##*/}
		host=${host%.pub}
		[[ -f $host_key_dir/$host.key.sops ]] ||
			die "orphaned public host key: $file"
	done
}

stage_host() {
	local host=$1
	local root=$2
	local force=${3:-}
	local prefix
	local ssh_dir
	local private_key_file

	validate_host "$host"
	[[ -d $root ]] || die "staging root does not exist: $root"
	[[ -z $force || $force == "--force" ]] || usage
	check_host "$host"
	set_bundle_paths "$host"

	if [[ $root == "/" ]]; then
		prefix=
	else
		prefix=${root%/}
	fi
	ssh_dir=$prefix/etc/ssh

	if [[ $force != "--force" ]] &&
		[[ -e $ssh_dir/ssh_host_ed25519_key ||
			-L $ssh_dir/ssh_host_ed25519_key ||
			-e $ssh_dir/ssh_host_ed25519_key.pub ||
			-L $ssh_dir/ssh_host_ed25519_key.pub ]]; then
		die "target host key already exists under '$ssh_dir'; use --force to replace it"
	fi

	ensure_scratch_dir
	private_key_file=$scratch_dir/$host.stage.key
	sops decrypt --output-type binary "$encrypted_key" >"$private_key_file"
	chmod 0600 "$private_key_file"
	validate_key_pair "$private_key_file" "$public_key"

	install -d -m 0755 "$ssh_dir"
	install -m 0644 "$public_key" "$ssh_dir/ssh_host_ed25519_key.pub"
	install -m 0600 "$private_key_file" "$ssh_dir/ssh_host_ed25519_key"
	echo "Staged host identity for '$host' under '$ssh_dir'."
}

for command in git install mktemp nu sops ssh-keygen ssh-to-age; do
	require_command "$command"
done
[[ -f $sops_config ]] || die "SOPS configuration not found: $sops_config"

action=${1:-}
case $action in
create)
	(($# == 2)) || usage
	create_host "$2"
	;;
import)
	(($# == 3)) || usage
	import_host "$2" "$3"
	;;
check)
	(($# <= 2)) || usage
	if (($# == 2)); then
		check_host "$2"
	else
		check_all_hosts
	fi
	;;
stage)
	(($# == 3 || $# == 4)) || usage
	stage_host "$2" "$3" "${4:-}"
	;;
*)
	usage
	;;
esac
