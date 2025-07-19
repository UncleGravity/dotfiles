{
  pkgs,
  wrapper-manager,
}:
# -----------------------------------------------------------------------------
# All wrapper-manager modules go here.
# https://github.com/viperML/wrapper-manager/
#
# 1.  `modules` is a hand-maintained list of files, each exporting a
#     wrapper-manager module (attrset).
# 2.  We call `wrapper-manager.lib` once with that list.
# 3.  We return:
#       • every wrapped derivation under its name   (e.g. `hello`)
#       • a `build` attrset containing { packages, toplevel, … } for bulk use
#
# Example usage after importing this attrset as `wrapped`:
#
#   nix run .#wrapped.hello
#   environment.systemPackages = builtins.attrValues wrapped.build.packages;
# -----------------------------------------------------------------------------
let
  wmEval = wrapper-manager.lib {
    inherit pkgs;
    modules = [
      ./hello.nix
      ./helix
      # add more modules here (./git.nix, ./fzf.nix, …)
    ];
  };
in
  # Forward individual wrappers AND bulk helpers (`build` attrset).
  wmEval.config.build.packages // {build = wmEval.config.build;}
