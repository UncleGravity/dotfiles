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
          age
          nh
          nix-output-monitor
          opentofu
          just
          nix-tree
          statix
          omnix
          cachix
          coreutils
          diffutils
          jq
          nushell
          openssh
          shellcheck
          sops
          ssh-to-age
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
