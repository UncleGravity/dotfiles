{
  inputs,
  self,
  ...
}: let
  # These constructors preserve the existing outputs until Clan owns the machines.
  inherit (inputs.nixpkgs) lib;

  mkHomeManagerConfig = {
    platform,
    username,
    hostname,
    homeStateVersion,
    homeModule ? ../machines/${platform}/${hostname}/home.nix,
  }: {
    home-manager = {
      extraSpecialArgs = {
        inherit inputs username;
      };
      sharedModules = [../modules/home];
      useGlobalPkgs = true;
      useUserPackages = true;
      users.${username} = {
        imports = [homeModule];
        home.stateVersion = homeStateVersion;
      };
    };
  };

  mkDarwin = {
    system,
    username,
    hostname,
    systemStateVersion,
    homeStateVersion,
  }:
    inputs.darwin.lib.darwinSystem {
      specialArgs = {
        inherit inputs username hostname homeStateVersion;
      };
      modules = [
        inputs.sops-nix.darwinModules.sops
        inputs.home-manager.darwinModules.home-manager
        inputs.nix-homebrew.darwinModules.nix-homebrew
        ../modules/darwin
        ../machines/darwin/${hostname}/configuration.nix
        (mkHomeManagerConfig {
          platform = "darwin";
          inherit username hostname homeStateVersion;
        })
        {
          nix-homebrew = {
            enable = true;
            user = username;
            autoMigrate = true;
            mutableTaps = false;
            taps = {
              "homebrew/homebrew-core" = inputs.homebrew-core;
              "homebrew/homebrew-cask" = inputs.homebrew-cask;
            };
          };

          nixpkgs = {
            hostPlatform = system;
            config.allowUnfree = true;
          };

          system.stateVersion = systemStateVersion;
        }
      ];
    };
in {
  flake = {
    darwinConfigurations.banana = mkDarwin {
      system = "aarch64-darwin";
      username = "angel";
      hostname = "banana";
      systemStateVersion = 6;
      homeStateVersion = "25.05";
    };

    lib.inference = import ../packages/inference/nix/lib {inherit lib;};
    nixosModules.inference = import ../packages/inference/nix/modules;
  };
}
