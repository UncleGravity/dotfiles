{ inputs }:
final: prev: {
  zig = inputs.zig.packages.${prev.system}.master;
}