{
  inputs,
  lib,
  self,
  ...
}: let
  sparkNodes = import ../modules/nixos/profiles/spark/nodes.nix;

  mkSparkMachine = hostname: node: {
    _module.args = {
      inherit hostname node sparkNodes;
    };

    imports = [
      ../modules/nixos
      self.nixosModules.inference
      inputs.dgx-spark.nixosModules.dgx-spark
      inputs.home-manager.nixosModules.home-manager
    ];

    clan.core.enableRecommendedDefaults = false;

    # Preserve the pre-Clan values against unconditional Clan ZFS defaults.
    networking.hostId = null;
    boot.zfs.forceImportRoot = true;

    nixpkgs = {
      hostPlatform = "aarch64-linux";
      config.allowUnfree = true;
    };

    system = {
      stateVersion = "26.05";
      configurationRevision = self.rev or self.dirtyRev or self.narHash;
    };

    home-manager = {
      extraSpecialArgs = {
        inherit inputs;
        username = "angel";
      };
      sharedModules = [../modules/home];
      useGlobalPkgs = true;
      useUserPackages = true;
      users.angel = {
        imports = [../modules/home/profiles/spark.nix];
        home.stateVersion = "26.05";
      };
    };
  };
in {
  imports = [inputs.clan-core.flakeModules.default];

  flake.sparkNodes = sparkNodes;

  clan = {
    meta = {
      name = "angelnet";
      domain = "angel.pizza";
    };

    specialArgs = {
      inherit inputs;
      username = "angel";
    };

    inventory.machines =
      {
        banana = {
          machineClass = "darwin";
          deploy.targetHost = "angel@banana";
        };
        kiwi.deploy.targetHost = "angel@kiwi";
        portal.deploy.targetHost = "angel@portal";
        sisyphus.deploy.targetHost = "angel@sisyphus";
      }
      // lib.mapAttrs (hostname: _: {
        deploy.targetHost = "angel@${hostname}";
      })
      sparkNodes;

    machines =
      {
        banana = {
          _module.args.hostname = "banana";

          imports = [
            ../modules/darwin
            inputs.home-manager.darwinModules.home-manager
            inputs.nix-homebrew.darwinModules.nix-homebrew
          ];

          clan.core = {
            enableRecommendedDefaults = false;
            deployment.requireExplicitUpdate = true;
          };

          nixpkgs = {
            hostPlatform = "aarch64-darwin";
            config.allowUnfree = true;
          };

          system.stateVersion = 6;

          nix-homebrew = {
            enable = true;
            user = "angel";
            autoMigrate = true;
            mutableTaps = false;
            taps = {
              "homebrew/homebrew-core" = inputs.homebrew-core;
              "homebrew/homebrew-cask" = inputs.homebrew-cask;
            };
          };

          home-manager = {
            extraSpecialArgs = {
              inherit inputs;
              username = "angel";
            };
            sharedModules = [../modules/home];
            useGlobalPkgs = true;
            useUserPackages = true;
            users.angel = {
              imports = [../machines/banana/home.nix];
              home.stateVersion = "25.05";
            };
          };
        };

        kiwi = {
          _module.args.hostname = "kiwi";

          imports = [
            ../modules/nixos
            self.nixosModules.inference
            inputs.copyparty.nixosModules.default
            inputs.home-manager.nixosModules.home-manager
          ];

          clan.core.enableRecommendedDefaults = false;

          # Preserve the NixOS ZFS default overridden by Clan's core module.
          services.zfs.autoSnapshot.monthly = 12;

          nixpkgs = {
            hostPlatform = "x86_64-linux";
            config.allowUnfree = true;
          };

          system = {
            stateVersion = "24.11";
            configurationRevision = self.rev or self.dirtyRev or self.narHash;
          };

          home-manager = {
            extraSpecialArgs = {
              inherit inputs;
              username = "angel";
            };
            sharedModules = [../modules/home];
            useGlobalPkgs = true;
            useUserPackages = true;
            users.angel = {
              imports = [../machines/kiwi/home.nix];
              home.stateVersion = "25.05";
            };
          };
        };

        portal = {
          _module.args.hostname = "portal";

          imports = [
            ../modules/nixos
            self.nixosModules.inference
            inputs.home-manager.nixosModules.home-manager
          ];

          clan.core.enableRecommendedDefaults = false;

          # Preserve the pre-Clan values against unconditional Clan ZFS defaults.
          networking.hostId = null;
          boot.zfs.forceImportRoot = true;

          nixpkgs = {
            hostPlatform = "x86_64-linux";
            config.allowUnfree = true;
          };

          system = {
            stateVersion = "26.05";
            configurationRevision = self.rev or self.dirtyRev or self.narHash;
          };

          home-manager = {
            extraSpecialArgs = {
              inherit inputs;
              username = "angel";
            };
            sharedModules = [../modules/home];
            useGlobalPkgs = true;
            useUserPackages = true;
            users.angel = {
              imports = [../machines/portal/home.nix];
              home.stateVersion = "26.05";
            };
          };
        };

        sisyphus = {
          _module.args.hostname = "sisyphus";

          imports = [
            ../modules/nixos
            self.nixosModules.inference
            inputs.home-manager.nixosModules.home-manager
          ];

          clan.core.enableRecommendedDefaults = false;

          # Preserve the pre-Clan values against unconditional Clan ZFS defaults.
          networking.hostId = null;
          boot.zfs.forceImportRoot = true;

          nixpkgs = {
            hostPlatform = "x86_64-linux";
            config.allowUnfree = true;
          };

          system = {
            stateVersion = "26.05";
            configurationRevision = self.rev or self.dirtyRev or self.narHash;
          };

          home-manager = {
            extraSpecialArgs = {
              inherit inputs;
              username = "angel";
            };
            sharedModules = [../modules/home];
            useGlobalPkgs = true;
            useUserPackages = true;
            users.angel = {
              imports = [../machines/sisyphus/home.nix];
              home.stateVersion = "26.05";
            };
          };
        };
      }
      // lib.mapAttrs mkSparkMachine sparkNodes;
  };
}
