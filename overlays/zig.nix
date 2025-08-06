{inputs}:
#
final: prev: {
  zig = inputs.zig.packages.${prev.system}.master; # Latest master branch
  # zig = inputs.zig.packages.${prev.system}.master-2025-07-01; # Specific commit
  # zig = inputs.zig.packages.${prev.system}.0.14.1; $ Specific version (stable)
}
