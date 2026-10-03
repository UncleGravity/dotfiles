{inputs, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    nixosSystem =
      if pkgs.stdenv.hostPlatform.isx86_64
      then "x86_64-linux"
      else "aarch64-linux";
  in {
    checks =
      (import ../packages/inference/tests/nix {
        inherit pkgs;
        inferenceLib = inputs.self.lib.inference;
        inferencePackage = inputs.self.packages.${system}.inference;
        nixosLib = inputs.nixpkgs.lib;
        nixosPkgs = inputs.nixpkgs.legacyPackages.${nixosSystem};
      })
      // {
        githubWorkflows =
          pkgs.runCommand "github-workflows" {
            nativeBuildInputs = [pkgs.actionlint pkgs.shellcheck];
            src = ../.github;
          } ''
            cp -R "$src" .github
            # Let actionlint resolve local reusable workflows inside the build sandbox.
            mkdir .git
            # actionlint does not yet support self-repository actions or concurrency queues.
            actionlint \
              -ignore '^specifying action "\$/\.github/actions/(ntfy|free-up-space)" in invalid format because ref is missing\.' \
              -ignore '^unexpected key "queue" for "concurrency" section\.' \
              .github/workflows/*.yml
            touch "$out"
          '';
      };
  };
}
