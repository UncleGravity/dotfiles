{
  perSystem = {pkgs, ...}: {
    devShells = {
      default = pkgs.mkShell {
        name = "dotfiles";
        packages = with pkgs; [
          nh
          nix-output-monitor
          nixos-anywhere
          opentofu
          just
          nix-tree
          statix
          omnix
          cachix
          shellcheck
        ];
      };

      inference = pkgs.mkShell {
        name = "inference";
        packages = [pkgs.nodejs_24];
      };
    };
  };
}
