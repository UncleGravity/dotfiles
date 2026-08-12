{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    formatter = inputs.treefmt-nix.lib.mkWrapper pkgs {
      projectRootFile = "flake.nix";
      programs = {
        alejandra = {
          enable = true;
          excludes = ["flake.nix"];
        };
        taplo.enable = true;
        yamlfmt = {
          enable = true;
          excludes = ["**/secrets.yaml" ".sops.yaml" "**/.sops.yaml" "**/secrets/*.yaml"];
        };
        prettier = {
          enable = true;
          includes = ["*.json"];
        };
        just.enable = true;
        shfmt = {
          enable = true;
          includes = ["*.sh" "*.zsh" "*.bash" ".env" ".envrc"];
          excludes = ["**/p10k.zsh" "**/powerlevel10k.zsh"];
        };
      };
    };
  };
}
