{
  perSystem = {
    config,
    pkgs,
    ...
  }: {
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
          config.packages.clan
        ];
      };

      inference = pkgs.mkShell {
        name = "inference";
        packages = [pkgs.nodejs_24];
      };
    };
  };
}
