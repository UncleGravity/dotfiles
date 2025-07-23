{ inputs }:[

#   # Option . Declare overlays in this file
#   (final: prev: {

#   zig = inputs.zig.packages.${prev.system}.master;

#   # Personal packages (scripts + wrapped) grouped under `my.*`
#   my = prev.lib.recurseIntoAttrs {
#     wrappers = inputs.self.packages.${prev.system}.wrappers;
#     scripts  = inputs.self.packages.${prev.system}.scripts;
#   };
# })

  # Option 2. Declare overlays in separate files
  # (import ./zig.nix         { inherit inputs; })
  (import ./my.nix { inherit inputs; })

]
