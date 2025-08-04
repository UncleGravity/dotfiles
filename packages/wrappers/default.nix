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
    specialArgs = { inherit inputs; };
    modules = [
      ./hello.nix
      ./helix
      ./nvim
      # add more modules here (./git.nix, ./fzf.nix, …)
    ];
  };
in {
  packages = wmEval.config.build.packages; # Used by flake "apps" output, to call each script individually from terminal with `nix run .#<name>` or `nix run .#apps.<system>.<name>
  toplevel = wmEval.config.build.toplevel; # Used by flake "packages" output, passed to systemPackages list for bulk install of all scripts with `inputs.self.packages.${pkgs.system}.wrapped.<name>`
}
