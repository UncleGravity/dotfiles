# Builds the GitHub Actions matrix for all flake configurations.
# Invoked by action.yml via:
#   nix eval --json --impure --file ./discover.nix --argstr flakePath "$PWD"
{ flakePath }:
let
  flake = builtins.getFlake flakePath;

  # Map nix systems to GitHub-hosted runner labels
  systemToRunner = system: {
    "x86_64-linux"   = "ubuntu-latest";
    "aarch64-linux"  = "ubuntu-24.04-arm";
    "aarch64-darwin" = "macos-latest";
    "x86_64-darwin"  = "macos-13";
  }.${system} or "ubuntu-latest";

  # Collect a single config family (nixos/darwin/home) into matrix entries
  collect = { type, configKey, attrSuffix }:
    let configs = flake.${configKey} or {}; in
    builtins.attrValues (builtins.mapAttrs (name: cfg: {
      inherit name type;
      system = cfg.pkgs.system;
      runner = systemToRunner cfg.pkgs.system;
      attr   = ".#${configKey}.${name}.${attrSuffix}";
    }) configs);
in
  (collect { type = "nixos";  configKey = "nixosConfigurations";  attrSuffix = "config.system.build.toplevel"; })
  ++ (collect { type = "darwin"; configKey = "darwinConfigurations"; attrSuffix = "system"; })
  ++ (collect { type = "home";   configKey = "homeConfigurations";   attrSuffix = "activationPackage"; })
