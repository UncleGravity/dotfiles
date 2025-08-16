{
  pkgs,
  wrapper-manager,
  inputs,
}:
# -----------------------------------------------------------------------------
# All wrapper-manager modules go here.
# https://github.com/viperML/wrapper-manager/
# Reasoning: https://ayats.org/blog/no-home-manager
#
# Returns both individual packages and the toplevel bundle for clean usage:
#   • packages: Individual wrapped derivations for apps
#   • toplevel: Single bundle derivation for systemPackages
# -----------------------------------------------------------------------------
let
  wmEval = wrapper-manager.lib {
    inherit pkgs;
    specialArgs = {inherit inputs;};
    modules = [
      ./hello.nix
      ./helix
      # add more modules here (./git.nix, ./fzf.nix, …)
    ];
  };
in {
  inherit (wmEval.config.build) packages;
  inherit (wmEval.config.build) toplevel;
}
