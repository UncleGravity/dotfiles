{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "bootstrap";
  runtimeInputs = with pkgs; [ nh nix jq ];

  text = ''
    # --------------------------------------------------------------------
    # Bootstrap script for Nix flakes
    #  - Detects the host’s platform (darwin | nixos)
    #  - Evaluates the flake once to obtain per-host binary-cache info
    #  - Exports it via $NIX_CONFIG and calls `nh <platform> switch`
    # --------------------------------------------------------------------
    #
    # Get available hostnames from flake
    get_available_hosts() {
      local darwin_hosts nixos_hosts
      darwin_hosts=$(nix eval --json .#darwinConfigurations --apply 'builtins.attrNames' 2>/dev/null | jq -r '.[]' | tr '\n' ' ')
      nixos_hosts=$(nix eval --json .#nixosConfigurations --apply 'builtins.attrNames' 2>/dev/null | jq -r '.[]' | tr '\n' ' ')

      echo "Available hostnames:"
      [[ -n "$darwin_hosts" ]] && echo "  Darwin: $darwin_hosts"
      [[ -n "$nixos_hosts" ]] && echo "  NixOS:  $nixos_hosts"
    }

    usage() {
      echo "Usage: bootstrap <hostname>"
      echo ""
      get_available_hosts
      exit 1
    }

    [[ $# -eq 1 ]] || usage
    hostname=$1

    # One nix-eval to get everything we need in JSON
    host_json=$(nix eval --impure --json --expr "
    let
      flake      = builtins.getFlake (toString ./.);
      hostname   = \"$hostname\";
      isDarwin   = builtins.hasAttr hostname flake.darwinConfigurations;
      isNixOS    = builtins.hasAttr hostname flake.nixosConfigurations;
      platform   = if isDarwin then \"darwin\"
                  else if isNixOS then \"os\"
                  else throw \"Unknown host\";
      target   = if platform == \"darwin\"
                 then flake.darwinConfigurations
                 else flake.nixosConfigurations;
      cfgPath  = (builtins.getAttr hostname target).config.nix.settings;
    in {
      inherit platform;
      substituters        = cfgPath.substituters or [];
      trusted-public-keys = cfgPath.trusted-public-keys or [];
    }")

    platform=$(jq -r '.platform' <<< "$host_json")
    substituters=$(jq -r '.substituters | join(" ")' <<< "$host_json")
    trusted_keys=$(jq -r '."trusted-public-keys" | join(" ")' <<< "$host_json")

    export NIX_CONFIG="
      extra-substituters = $substituters
      extra-trusted-public-keys = $trusted_keys
    "

    echo "🚀 Bootstrapping $hostname ($platform)..."
    echo "✅ Cache configuration loaded"
    echo "With NIX_CONFIG = $NIX_CONFIG"
    echo

    exec nh "$platform" switch . -H "$hostname"
  '';
}
