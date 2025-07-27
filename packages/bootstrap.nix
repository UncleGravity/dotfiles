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

    usage() {
      echo "Usage: bootstrap <hostname>"
      echo
      echo "Available hostnames:"
      nix eval --raw --expr '
        let flake = builtins.getFlake ./.;
        in builtins.concatStringsSep "\n" (
          map (h: "  darwin: " + h) (builtins.attrNames flake.darwinConfigurations)
        ++ map (h: "  nixos:  " + h) (builtins.attrNames flake.nixosConfigurations)
        )'
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
