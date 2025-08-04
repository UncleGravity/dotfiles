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

    wrapper-manager.url = "github:viperML/wrapper-manager";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Installs homebrew with nix.
    # Does not manage formulae, just installs homebrew.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    virby = {
      url = "github:quinneden/virby-nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    television = {
      url = "github:alexpasmantier/television";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    optnix.url = "github:water-sucks/optnix";

    # ---------------------------------------------------------------------------------------------
    # Overlay Inputs

    # Zig nightly
    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ---------------------------------------------------------------------------------------------
    # Non Flake Inputs

    tmux-tokyo-night = {
      url = "github:fabioluciano/tmux-tokyo-night";
      flake = false;
    };
  };

  outputs = inputs @ { nixpkgs, ... }:
  let
    # --------------------------------------------------------------------------
    # Overlays
    # --------------------------------------------------------------------------
    overlays = import ./overlays { inherit inputs; };

    # --------------------------------------------------------------------------
    # Platform Helpers
    # --------------------------------------------------------------------------
    systems = {
      aarch64-linux = "aarch64-linux";
      x86_64-linux = "x86_64-linux";
      aarch64-darwin = "aarch64-darwin";
      x86_64-darwin = "x86_64-darwin";
    };

    # Map a function over every supported system, passing it { system, pkgs }
    forAllSystems = f:
      nixpkgs.lib.genAttrs (builtins.attrNames systems) (system:
        let
          pkgs = import nixpkgs { inherit system overlays; };
        in f { inherit system pkgs; });

    # --------------------------------------------------------------------------
    # System config helpers
    # --------------------------------------------------------------------------
    mkHomeManagerConfig = { platform, username, hostname, homeStateVersion,}:{
      home-manager = {
        extraSpecialArgs = {
          inherit inputs username;
        };
        sharedModules = [
          inputs.nixvim.homeManagerModules.nixvim
          ./modules/home
        ];
        useGlobalPkgs = true; # Share pkgs with darwin/nixos
        useUserPackages = true;
        # This assumes that the home.nix file is in the machines/${platform}/${hostname} directory.
        # ie. This only works for a single user.
        users.${username} = {
          imports = [ ./machines/${platform}/${hostname}/home.nix ];
          home.stateVersion = homeStateVersion;
        };
      };
    };

    mkNixos = { system, username, hostname, systemStateVersion, homeStateVersion }:
      nixpkgs.lib.nixosSystem {
        # inherit system;
        specialArgs = {
          inherit inputs;
          inherit username hostname homeStateVersion;
        };
        modules = [
          # Input modules
          inputs.home-manager.nixosModules.home-manager
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops

          ./modules/nixos # My modules
          ./machines/nixos/${hostname}/configuration.nix # System config

          # Home Manager Config
          (mkHomeManagerConfig {platform = "nixos"; inherit username hostname homeStateVersion;})

          # -- Global NixOS Config ------------------------------------------
          {
            # Nixpkgs Config
            nixpkgs = {
              hostPlatform = system;
              overlays = overlays;
              config.allowUnfree = true; # buhaoyisi duibuqi
            };
            system.stateVersion = systemStateVersion; # no change or u will regret
          }
          # -----------------------------------------------------------------
        ];
      };

    mkDarwin = { system, username, hostname, systemStateVersion, homeStateVersion }:
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
          (mkHomeManagerConfig {platform = "darwin"; inherit username hostname homeStateVersion;})

          # -- Global Darwin Config -----------------------------------------
          {
            # Nix-Homebrew
            nix-homebrew = {
              enable = hostname != "BENGKUI"; # false for bengkui
              user = username; # Assuming username is the same as nix-homebrew user
              autoMigrate = true;
            };

            # Nixpkgs Config
            nixpkgs = {
              hostPlatform = system;
              overlays = overlays;
              config.allowUnfree = true; # gomenasai
            };

            system.stateVersion = systemStateVersion; # no change or u will regret
          }
          # ---------------------------------------------------------------
        ];
      };

    mkHomeManagerSystem = { system, pkgs, username, homeStateVersion }:
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs username homeStateVersion;
        };
        modules = [
          # Input Modules
          inputs.nixvim.homeManagerModules.nixvim

          ./modules/home # My Home Modules
          ./machines/hm/${username}/home.nix # Home Manager Config
          # -- Global Home-Manager Config -----------------------------------
          {
            # Nixpkgs Config
            nixpkgs = {
              # hostPlatform = system;
              overlays = overlays;
              config.allowUnfree = true; # 歹勢 歹勢
            };
            home.stateVersion = homeStateVersion; # no toques wey
          }
          # -----------------------------------------------------------------
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

      # Darwin - BENGKUI
      BENGKUI = mkDarwin {
        system = systems.aarch64-darwin;
        username = "useradmin";
        hostname = "BENGKUI";
        systemStateVersion = 4;
        homeStateVersion = "24.05";
      };

      # Darwin - BASURA
      BASURA = mkDarwin {
        system = systems.x86_64-darwin;
        username = "angel";
        hostname = "BASURA";
        systemStateVersion = 6;
        homeStateVersion = "24.11";
      };
    };

    # --------------------------------------------------------------------------
    # NixOS Configurations
    # --------------------------------------------------------------------------
    nixosConfigurations = {
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
    };

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
    packages = forAllSystems ({ system, pkgs, ... }:
      import ./packages {
        inherit inputs system pkgs;
        inherit (pkgs) lib;
        wrapper-manager = inputs.wrapper-manager;
      }
    );

    # --------------------------------------------------------------------------
    # Development shells
    # --------------------------------------------------------------------------
    devShells = forAllSystems ({ pkgs, system, ... }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nh
            nix-output-monitor
            just
            nix-tree
            statix
            vulnix
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
    formatter = forAllSystems ({ pkgs, ... }:
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

    # checks."<system>"."<name>" = derivation; # nix flake check
    # packages."<system>"."<name>" = derivation; # nix build .#<name>
    # apps."<system>"."<name>" = { type = "app"; program = "<store-path>"; }; # nix run .#<name>
    # formatter."<system>" = derivation; # nix fmt
    # nixosConfigurations."<hostname>" = {};
    # devShells."<system>".default = derivation; # nix develop
  };
}
