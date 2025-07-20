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

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ---------------------------------------------------------------------------------------------
    # Overlay Inputs

    # Zig nightly
    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ---------------------------------------------------------------------------------------------
    # Non Flake Inputs

    # Tmux plugins
    tmux-vim-navigator = {
      url = "github:christoomey/vim-tmux-navigator";
      flake = false;
    };
    tmux-tokyo-night = {
      url = "github:fabioluciano/tmux-tokyo-night";
      flake = false;
    };
  };

  outputs = inputs @ { self, nixpkgs, home-manager, darwin, ... }:
  let
    # --------------------------------------------------------------------------
    # Platform Helpers
    # --------------------------------------------------------------------------
    systems = {
      aarch64-linux = "aarch64-linux";
      x86_64-linux = "x86_64-linux";
      aarch64-darwin = "aarch64-darwin";
      x86_64-darwin = "x86_64-darwin";
    };

    # Map a function over every supported system, passing it { system, pkgs, lib }
    forAllSystems = f:
      nixpkgs.lib.genAttrs (builtins.attrNames systems) (system:
        let
          pkgs = import nixpkgs { inherit system overlays; };
        in f { inherit system pkgs; lib = pkgs.lib; });

    # --------------------------------------------------------------------------
    # Overlays
    # --------------------------------------------------------------------------
    overlays = [
      (final: prev: {
        # --- 1. nixpkgs
        zig = inputs.zig.packages.${prev.system}.master;

        # --- 2. Personal packages (scripts + wrapped)
        my = prev.lib.recurseIntoAttrs {
          wrappers = inputs.self.packages.${prev.system}.wrappers;
          scripts = inputs.self.packages.${prev.system}.scripts;
        };
      })
    ];

    # --------------------------------------------------------------------------
    # System config helpers
    # --------------------------------------------------------------------------
    mkHomeManagerConfig = { system, username, hostname, homeStateVersion,}:{
      home-manager = {
        extraSpecialArgs = {
          inherit inputs self username homeStateVersion;
        };
        useGlobalPkgs = true;
        useUserPackages = true;
        # This assumes that the home.nix file is in the machines/${system}/${hostname} directory.
        # ie. This only works for a single user.
        users.${username} = import ./machines/${system}/${hostname}/home.nix;
        sharedModules = [
          inputs.nixvim.homeManagerModules.nixvim
          ./modules/home
        ];
      };
    };

    mkNixos = { system, username, hostname, systemStateVersion, homeStateVersion }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs self;
          inherit username hostname systemStateVersion homeStateVersion;
        };
        modules = [
          # Input modules
          inputs.home-manager.nixosModules.home-manager
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops

          # My modules
          ./modules/nixos

          # System config
          ./machines/${system}/${hostname}/configuration.nix

          # Home Manager Config
          (mkHomeManagerConfig {inherit system username hostname homeStateVersion;})

          # Overlays
          { nixpkgs.overlays = overlays; }
        ];
      };

    mkDarwin = { system, username, hostname, systemStateVersion, homeStateVersion }:
      darwin.lib.darwinSystem {
        inherit system;
        specialArgs = {
          inherit inputs self username hostname systemStateVersion homeStateVersion;
        };
        modules = [
          # System Config
          ./machines/${system}/${hostname}/configuration.nix
          inputs.sops-nix.darwinModules.sops

          # Input Modules
          home-manager.darwinModules.home-manager
          inputs.nix-homebrew.darwinModules.nix-homebrew

          # My modules
          ./modules/darwin

          # Home Manager Config
          (mkHomeManagerConfig {inherit system username hostname homeStateVersion;})

          {
            # Nix-Homebrew Config
            nix-homebrew = {
              enable = hostname != "BENGKUI"; # false for bengkui
              user = username; # Assuming username is the same as nix-homebrew user
              autoMigrate = true;
            };

            # Overlays
            nixpkgs.overlays = overlays;
          }
        ];
      };

    mkHomeManagerSystem = { system, pkgs, username, homeStateVersion }:
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs self username homeStateVersion;
        };
        modules = [
          # Input Modules
          inputs.nixvim.homeManagerModules.nixvim

          # My Home Modules
          ./modules/home

          # Home Manager Config
          ./machines/${system}/${username}/home.nix
        ];
      };

  in {
    # Darwin Configurations
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

    # NixOS Configurations
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

    # Home Manager Configurations
    homeConfigurations = {
      # Raspberry Pi (home-manager only)
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
        inherit system pkgs;
        wrapper-manager = inputs.wrapper-manager;
      }
    );

    # --------------------------------------------------------------------------
    # Apps - for `nix run .#<name>` to support wrappers + scripts bundles
    # --------------------------------------------------------------------------
    apps = forAllSystems ({ system, pkgs, ... }:
      let
        # Get the individual packages to create apps from
        scriptsResult = pkgs.callPackage ./packages/scripts {inherit system;};
        wrappedResult = pkgs.callPackage ./packages/wrappers {wrapper-manager = inputs.wrapper-manager;};

        # Both now provide clean packages attribute sets
        allPackages = scriptsResult.packages // wrappedResult.packages;

        mkApp = name: package: {
          type = "app";
          program = "${package}/bin/${package.meta.mainProgram or name}";
        };
      in
        builtins.mapAttrs mkApp allPackages
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
            # self.packages.${system}.scripts  # Your scripts available in dev shell
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
