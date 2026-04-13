#!/usr/bin/env bash
set -euo pipefail

PROFILE_FILE=$(mktemp /tmp/nix-profile.XXXXXX)
trap 'rm -f "$PROFILE_FILE"' EXIT

# Determine what to evaluate
if [ -n "${1:-}" ]; then
    # Hostname provided — find it in flake outputs
    HOST="$1"
    ATTR=""
    for config_type in darwinConfigurations nixosConfigurations homeConfigurations; do
        if nix eval --impure --json --expr "builtins.hasAttr \"${HOST}\" (builtins.getFlake (toString ./.)).${config_type}" 2>/dev/null | grep -q "true"; then
            case "$config_type" in
                nixosConfigurations)  ATTR=".#${config_type}.${HOST}.config.system.build.toplevel" ;;
                darwinConfigurations) ATTR=".#${config_type}.${HOST}.system" ;;
                homeConfigurations)   ATTR=".#${config_type}.${HOST}.activationPackage" ;;
            esac
            break
        fi
    done
    if [ -z "$ATTR" ]; then
        echo "Host '${HOST}' not found in any flake configuration." >&2
        exit 1
    fi
elif [ -d /etc/nixos ]; then
    ATTR=".#nixosConfigurations.$(hostname).config.system.build.toplevel"
elif command -v darwin-rebuild >/dev/null 2>&1; then
    ATTR=".#darwinConfigurations.$(scutil --get ComputerName).system"
elif command -v home-manager >/dev/null 2>&1; then
    ATTR=".#homeConfigurations.$(whoami).activationPackage"
else
    echo "Unsupported system type. Pass a hostname: $0 <host>" >&2
    exit 1
fi

echo "Profiling: nix eval $ATTR"
echo ""

# Run evaluation with profiler and time it
START=$(date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))')
nix eval "$ATTR" --raw \
    --eval-profiler flamegraph \
    --eval-profile-file "$PROFILE_FILE" \
    > /dev/null 2>&1
END=$(date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))')
ELAPSED_MS=$(( (END - START) / 1000000 ))

TOTAL=$(wc -l < "$PROFILE_FILE" | tr -d ' ')

echo "Eval time:    ${ELAPSED_MS}ms"
echo "Samples:      ${TOTAL}"
echo ""

# Top source directories by sample count (auto-discovers categories)
echo "-- Breakdown by source --"
grep -oE '/nix/store/[^;]+' "$PROFILE_FILE" \
    | sed -E 's|/nix/store/[a-z0-9]+-source/||g' \
    | grep -oE '^[^:]+' \
    | sed -E 's|/[^/]*$||' \
    | sort | uniq -c | sort -rn \
    | head -10 \
    | awk '{printf "  %6d  %s\n", $1, $2}'
echo ""

# Top leaf functions (where time is actually spent)
echo "-- Top 10 hotspot functions --"
awk -F';' '{print $NF}' "$PROFILE_FILE" \
    | sed 's/ [0-9]*$//' \
    | sed -E 's|/nix/store/[a-z0-9]+-source/||g' \
    | sort | uniq -c | sort -rn \
    | head -10 \
    | awk '{count=$1; $1=""; printf "  %6d  %s\n", count, substr($0,2)}'
echo ""

# Generate flamegraph if available
FLAMEGRAPH_SVG="flamegraph.svg"
if command -v flamegraph.pl > /dev/null 2>&1; then
    flamegraph.pl "$PROFILE_FILE" > "$FLAMEGRAPH_SVG"
    echo "Flamegraph: $FLAMEGRAPH_SVG"
elif nix shell nixpkgs#flamegraph -c flamegraph.pl "$PROFILE_FILE" > "$FLAMEGRAPH_SVG" 2>/dev/null; then
    echo "Flamegraph: $FLAMEGRAPH_SVG"
else
    echo "Install flamegraph for SVG output: nix shell nixpkgs#flamegraph"
fi
