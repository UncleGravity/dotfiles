{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # nix-darwin
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dgx-spark = {
      url = "github:graham33/nixos-dgx-spark";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Installs homebrew with nix.
    # Does not manage formulae, just installs homebrew.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Secrets
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    virby = {
      url = "github:quinneden/virby-nix-darwin";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tmux-powerkit = {
      url = "github:fabioluciano/tmux-powerkit";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ---------------------------------------------------------------------------------------------
    # Overlay Inputs

    # Zig nightly
    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    # --------------------------------------------------------------------------
    # Overlays
    # --------------------------------------------------------------------------
    overlays = import ./overlays {inherit inputs;};
    sparkNodes = import ./machines/nixos/spark/nodes.nix;

    # --------------------------------------------------------------------------
    # Platform Helpers
    # --------------------------------------------------------------------------
    systems = {
      aarch64-linux = "aarch64-linux";
      x86_64-linux = "x86_64-linux";
      aarch64-darwin = "aarch64-darwin";
      # x86_64-darwin = "x86_64-darwin";
    };

    # Map a function over every supported system, passing it { system, pkgs }
    forAllSystems = f:
      nixpkgs.lib.genAttrs (builtins.attrNames systems) (system: let
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };
      in
        f {inherit system pkgs;});

    # --------------------------------------------------------------------------
    # System config helpers
    # --------------------------------------------------------------------------
    mkHomeManagerConfig = {
      platform,
      username,
      hostname,
      homeStateVersion,
      homeModule ? ./machines/${platform}/${hostname}/home.nix,
    }: {
      home-manager = {
        extraSpecialArgs = {
          inherit inputs username;
        };
        sharedModules = [
          ./modules/home
        ];
        useGlobalPkgs = true; # Share pkgs with darwin/nixos
        useUserPackages = true;
        # This assumes that the home.nix file is in the machines/${platform}/${hostname} directory.
        # ie. This only works for a single user.
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
      machineModule ? ./machines/nixos/${hostname}/configuration.nix,
      homeModule ? ./machines/nixos/${hostname}/home.nix,
      extraModules ? [],
      extraSpecialArgs ? {},
      withHomeManager ? true,
    }:
      nixpkgs.lib.nixosSystem {
        # inherit system;
        specialArgs =
          {
            inherit inputs;
            inherit username hostname homeStateVersion;
          }
          // extraSpecialArgs;
        modules =
          [
            # Input modules
            inputs.disko.nixosModules.disko
            inputs.sops-nix.nixosModules.sops

            ./modules/nixos # My modules
          ]
          ++ extraModules
          ++ [machineModule]
          ++ nixpkgs.lib.optional withHomeManager inputs.home-manager.nixosModules.home-manager
          ++ nixpkgs.lib.optional withHomeManager (mkHomeManagerConfig {
            platform = "nixos";
            inherit username hostname homeStateVersion homeModule;
          })
          ++ [
            # -- Global NixOS Config ------------------------------------------
            {
              # Nixpkgs Config
              nixpkgs = {
                inherit overlays;
                hostPlatform = system;
                config.allowUnfree = true; # buhaoyisi duibuqi
              };
              system.stateVersion = systemStateVersion; # no change or u will regret
              # Every host can report the git commit it runs: nixos-version --configuration-revision
              system.configurationRevision = self.rev or self.dirtyRev or "unknown";
            }
            # -----------------------------------------------------------------
          ];
      };

    sparkConfigurations =
      nixpkgs.lib.mapAttrs (
        hostname: node:
          mkNixos {
            system = systems.aarch64-linux;
            username = "angel";
            inherit hostname;
            systemStateVersion = "26.05";
            homeStateVersion = "26.05";
            machineModule = ./machines/nixos/spark/configuration.nix;
            homeModule = ./machines/nixos/spark/home.nix;
            extraModules = [inputs.dgx-spark.nixosModules.dgx-spark];
            extraSpecialArgs = {inherit node sparkNodes;};
          }
      )
      sparkNodes;

    mkDarwin = {
      system,
      username,
      hostname,
      systemStateVersion,
      homeStateVersion,
    }:
      inputs.darwin.lib.darwinSystem {
        # inherit system;
        specialArgs = {
          inherit inputs username hostname homeStateVersion;
        };
        modules = [
          # Input Modules
          inputs.sops-nix.darwinModules.sops
          inputs.home-manager.darwinModules.home-manager
          inputs.nix-homebrew.darwinModules.nix-homebrew
          inputs.virby.darwinModules.default

          ./modules/darwin # My modules
          ./machines/darwin/${hostname}/configuration.nix # System Config

          # Home Manager Config
          (mkHomeManagerConfig {
            platform = "darwin";
            inherit username hostname homeStateVersion;
          })

          # -- Global Darwin Config -----------------------------------------
          {
            # Nix-Homebrew
            nix-homebrew = {
              enable = true;
              user = username; # Assuming username is the same as nix-homebrew user
              autoMigrate = true;
            };

            # Nixpkgs Config
            nixpkgs = {
              inherit overlays;
              hostPlatform = system;
              config.allowUnfree = true; # gomenasai
            };

            system.stateVersion = systemStateVersion; # no change or u will regret
          }
          # ---------------------------------------------------------------
        ];
      };

    mkHomeManagerSystem = {
      system,
      pkgs,
      username,
      homeStateVersion,
    }:
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs username homeStateVersion;
        };
        modules = [
          ./modules/home # My Home Modules
          ./machines/hm/${username}/home.nix # Home Manager Config
          # -- Global Home-Manager Config -----------------------------------
          {
            # Nixpkgs Config
            nixpkgs = {
              inherit overlays;
              # hostPlatform = system;
              config.allowUnfree = true; # 歹勢 歹勢
            };
            home.stateVersion = homeStateVersion; # no toques wey
          }
          # -----------------------------------------------------------------
        ];
      };

    mkMicrovm = {
      system,
      username,
      hostname,
      systemStateVersion,
      hostSystem ? systems.aarch64-darwin,
    }:
      nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs username hostname;
        };
        modules = [
          inputs.microvm.nixosModules.microvm
          ./machines/microvm/${hostname}.nix

          {
            nixpkgs = {
              hostPlatform = system;
              config.allowUnfree = true;
            };

            microvm.vmHostPackages = nixpkgs.legacyPackages.${hostSystem};
            system.stateVersion = systemStateVersion;
          }
        ];
      };
  in {
    # --------------------------------------------------------------------------
    # Darwin Configurations
    # --------------------------------------------------------------------------
    darwinConfigurations = {
      # Darwin - banana
      banana = mkDarwin {
        system = systems.aarch64-darwin;
        username = "angel";
        hostname = "banana";
        systemStateVersion = 6;
        homeStateVersion = "25.05";
      };
    };

    # --------------------------------------------------------------------------
    # NixOS Configurations
    # --------------------------------------------------------------------------
    nixosConfigurations =
      {
        # AI workstation
        sisyphus = mkNixos {
          system = systems.x86_64-linux;
          username = "angel";
          hostname = "sisyphus";
          systemStateVersion = "26.05";
          homeStateVersion = "26.05";
        };

        # kiwi (NAS)
        kiwi = mkNixos {
          system = systems.x86_64-linux;
          username = "angel";
          hostname = "kiwi";
          systemStateVersion = "24.11";
          homeStateVersion = "25.05";
        };

        # Development VM
        nixos = mkNixos {
          system = systems.aarch64-linux;
          username = "angel";
          hostname = "nixos";
          systemStateVersion = "24.05";
          homeStateVersion = "24.05";
        };

        # MicroVMs
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
      // sparkConfigurations;

    # --------------------------------------------------------------------------
    # Home Manager ONLY Configurations
    # --------------------------------------------------------------------------
    homeConfigurations = {
      # Raspberry Pi
      pi = mkHomeManagerSystem {
        system = systems.aarch64-linux;
        pkgs = nixpkgs.legacyPackages.${systems.aarch64-linux};
        username = "pi";
        homeStateVersion = "24.05";
      };
    };

    # --------------------------------------------------------------------------
    # Packages
    # --------------------------------------------------------------------------
    packages = forAllSystems ({
      system,
      pkgs,
      ...
    }:
      import ./packages {
        inherit inputs system pkgs;
        inherit (pkgs) lib;
      });

    # --------------------------------------------------------------------------
    # Development shells
    # --------------------------------------------------------------------------
    devShells = forAllSystems (
      {
        pkgs,
        system,
        ...
      }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nh
            nix-output-monitor
            nixos-anywhere
            just
            nix-tree
            statix
            # vulnix
            omnix
            cachix
            # inputs.self.nixosConfigurations.nixos.config.system.build.vm
            # inputs.self.packages.${system}.scripts  # Your scripts available in dev shell
          ];

          # shellHook = ''
          #   exec zsh
          # '';
        };
      }
    );

    # --------------------------------------------------------------------------
    # Default formatter - Run with `nix fmt .`
    formatter = forAllSystems (
      {pkgs, ...}:
        inputs.treefmt-nix.lib.mkWrapper pkgs {
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
        }
    );

    inherit sparkNodes;

    # checks."<system>"."<name>" = derivation; # nix flake check
    # packages."<system>"."<name>" = derivation; # nix build .#<name>
    # apps."<system>"."<name>" = { type = "app"; program = "<store-path>"; }; # nix run .#<name>
    # formatter."<system>" = derivation; # nix fmt
    # nixosConfigurations."<hostname>" = {};
    # devShells."<system>".default = derivation; # nix develop
  };
}
