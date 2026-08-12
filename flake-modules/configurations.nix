{
  inputs,
  self,
  ...
}: let
  # These constructors preserve the existing outputs until Clan owns the machines.
  inherit (inputs.nixpkgs) lib;

  overlays = import ../overlays {inherit inputs;};
  sparkNodes = import ../machines/nixos/spark/nodes.nix;

  systems = {
    aarch64-linux = "aarch64-linux";
    x86_64-linux = "x86_64-linux";
    aarch64-darwin = "aarch64-darwin";
  };

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

  mkNixos = {
    system,
    username,
    hostname,
    systemStateVersion,
    homeStateVersion,
    configDir ? ../machines/nixos/${hostname},
    machineModule ? configDir + "/configuration.nix",
    homeModule ? configDir + "/home.nix",
    extraModules ? [],
    extraSpecialArgs ? {},
    withHomeManager ? true,
  }:
    lib.nixosSystem {
      specialArgs =
        {
          inherit inputs username hostname homeStateVersion;
        }
        // extraSpecialArgs;
      modules =
        [
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops
          ../modules/nixos
          self.nixosModules.inference
        ]
        ++ extraModules
        ++ [machineModule]
        ++ lib.optional withHomeManager inputs.home-manager.nixosModules.home-manager
        ++ lib.optional withHomeManager (mkHomeManagerConfig {
          platform = "nixos";
          inherit username hostname homeStateVersion homeModule;
        })
        ++ [
          {
            nixpkgs = {
              inherit overlays;
              hostPlatform = system;
              config.allowUnfree = true;
            };
            system = {
              stateVersion = systemStateVersion;
              configurationRevision = self.rev or self.dirtyRev or "unknown";
            };
          }
        ];
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
            inherit overlays;
            hostPlatform = system;
            config.allowUnfree = true;
          };

          system.stateVersion = systemStateVersion;
        }
      ];
    };

  mkMicrovm = {
    system,
    username,
    hostname,
    systemStateVersion,
    hostSystem ? systems.aarch64-darwin,
  }:
    lib.nixosSystem {
      specialArgs = {
        inherit inputs username hostname;
      };
      modules = [
        inputs.microvm.nixosModules.microvm
        ../machines/microvm/${hostname}.nix
        {
          nixpkgs = {
            hostPlatform = system;
            config.allowUnfree = true;
          };

          microvm.vmHostPackages = inputs.nixpkgs.legacyPackages.${hostSystem};
          system.stateVersion = systemStateVersion;
        }
      ];
    };
in {
  flake = {
    darwinConfigurations.banana = mkDarwin {
      system = systems.aarch64-darwin;
      username = "angel";
      hostname = "banana";
      systemStateVersion = 6;
      homeStateVersion = "25.05";
    };

    nixosConfigurations =
      {
        sisyphus = mkNixos {
          system = systems.x86_64-linux;
          username = "angel";
          hostname = "sisyphus";
          systemStateVersion = "26.05";
          homeStateVersion = "26.05";
        };

        kiwi = mkNixos {
          system = systems.x86_64-linux;
          username = "angel";
          hostname = "kiwi";
          systemStateVersion = "24.11";
          homeStateVersion = "25.05";
          extraModules = [inputs.copyparty.nixosModules.default];
        };

        portal = mkNixos {
          system = systems.x86_64-linux;
          username = "angel";
          hostname = "portal";
          systemStateVersion = "26.05";
          homeStateVersion = "26.05";
        };

        dev = mkMicrovm {
          system = systems.aarch64-linux;
          username = "angel";
          hostname = "dev";
          systemStateVersion = "25.05";
        };

        small = mkMicrovm {
          system = systems.aarch64-linux;
          username = "angel";
          hostname = "small";
          systemStateVersion = "25.05";
        };
      }
      // lib.mapAttrs (
        hostname: node:
          mkNixos {
            system = systems.aarch64-linux;
            username = "angel";
            inherit hostname;
            systemStateVersion = "26.05";
            homeStateVersion = "26.05";
            configDir = ../machines/nixos/spark;
            extraModules = [inputs.dgx-spark.nixosModules.dgx-spark];
            extraSpecialArgs = {inherit node sparkNodes;};
          }
      )
      sparkNodes;

    inherit sparkNodes;

    lib.inference = import ../packages/inference/nix/lib {inherit lib;};
    nixosModules.inference = import ../packages/inference/nix/modules;
  };
}
