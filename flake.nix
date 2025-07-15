{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

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

    # ---------------------------------------------------------------------------------------------
    # Overlays

    # Opencode from upstream
    # opencode = {
    #   url = "github:sst/opencode/v0.3.2";
    #   flake = false;
    # };

    # Zig nightly
    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
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

  outputs = {
    self,
    nixpkgs,
    home-manager,
    darwin,
    ...
  } @ inputs: let
    systems = {
      aarch64-linux = "aarch64-linux";
      aarch64-darwin = "aarch64-darwin";
      x86_64-linux = "x86_64-linux";
      x86_64-darwin = "x86_64-darwin";
    };

    # Shared overlays for both NixOS and Darwin
    overlays = [
      (final: prev: {
        # opencode = inputs.nixpkgs_opencode.legacyPackages.${prev.system}.opencode;
        zig = inputs.zig.packages.${prev.system}.master;
        # opencode = prev.opencode.overrideAttrs (old: {
        #   version = "0.3.2";
        #   src = inputs.opencode;
        #   node_modules = old.node_modules.overrideAttrs (nmOld: {
        #     outputHash =
        #       if prev.system == "aarch64-darwin" then "sha256-uk8HQfHCKTAW54rNHZ1Rr0piZzeJdx6i4o0+xKjfFZs="
        #       else if prev.system == "x86_64-linux" then "sha256-1ZxetDrrRdNNOfDOW2uMwMwpEs5S3BLF+SejWcRdtik="
        #       else if prev.system == "aarch64-linux" then "sha256-gDQh8gfFKl0rAujtos1XsCUnxC2Vjyq9xH5FLZoNW5s="
        #       else throw "Unsupported system for opencode: ${prev.system}";
        #   });
        #   tui = old.tui.overrideAttrs (tuiOld: {
        #     vendorHash = "sha256-0vf4fOk32BLF9/904W8g+5m0vpe6i6tUFRXqDHVcMIQ=";
        #   });
        # });
      })
    ];

    mkHomeManagerConfig = {
      system,
      username,
      hostname,
      homeStateVersion,
    }: {
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

    mkNixos = {
      system,
      username,
      hostname,
      systemStateVersion,
      homeStateVersion,
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs self;
          inherit username hostname systemStateVersion homeStateVersion;
        };
        modules = [
          inputs.sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          ./modules/nixos
          ./machines/${system}/${hostname}/configuration.nix
          (mkHomeManagerConfig {inherit system username hostname homeStateVersion;})
          {
            nixpkgs.overlays = overlays;
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
      darwin.lib.darwinSystem {
        inherit system;
        specialArgs = {
          inherit inputs self username hostname systemStateVersion homeStateVersion;
        };
        modules = [
          ./modules/darwin
          ./machines/${system}/${hostname}/configuration.nix
          inputs.sops-nix.darwinModules.sops
          home-manager.darwinModules.home-manager
          (mkHomeManagerConfig {inherit system username hostname homeStateVersion;})
          inputs.nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              user = username; # Assuming username is the same as nix-homebrew user
              autoMigrate = true;
            };
            nixpkgs.overlays = overlays;
          }
        ];
      };

    mkHomeManagerSystem = {
      system,
      pkgs,
      username,
      homeStateVersion,
    }:
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs username homeStateVersion;
        };
        modules = [
          ./machines/${system}/${username}/home.nix
          inputs.nixvim.homeManagerModules.nixvim
          ./modules/home
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
    # homeConfigurations = {
    #   # Raspberry Pi (home-manager only)
    #   pi = mkHomeManagerSystem {
    #     system = systems.aarch64-linux;
    #     pkgs = nixpkgs.legacyPackages.${systems.aarch64-linux};
    #     username = "pi";
    #     homeStateVersion = "24.05";
    #   };
    # };

    # Packages
    packages = nixpkgs.lib.genAttrs (builtins.attrNames systems) (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        import ./packages {
          inherit inputs system pkgs;
        }
    );

    # Development shells
    devShells = nixpkgs.lib.genAttrs (builtins.attrNames systems) (system: {
      default = nixpkgs.legacyPackages.${system}.mkShell {
        packages = with nixpkgs.legacyPackages.${system}; [
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
    });

    # Default formatter - Run with `nix fmt .`
    formatter = nixpkgs.lib.genAttrs (builtins.attrNames systems) (
      system:
        nixpkgs.legacyPackages.${system}.alejandra
    );
  };
}
