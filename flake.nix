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
    nixpkgs_opencode.url = "github:nixos/nixpkgs/pull/419604/head";

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

    # AI coding agent
    opencode = {
      url = "github:sst/opencode";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs:
  let
    systems = {
      aarch64-linux = "aarch64-linux";
      aarch64-darwin = "aarch64-darwin";
      x86_64-linux = "x86_64-linux";
      x86_64-darwin = "x86_64-darwin";
    };

    # Shared overlays for both NixOS and Darwin
    overlays = [
      (final: prev: {
        opencode = inputs.nixpkgs_opencode.legacyPackages.${prev.system}.opencode;
        zig = inputs.zig.packages.${prev.system}.master;
      })
    ];

    mkHomeManagerConfig = { username, hostname, homeStateVersion }: {
      home-manager.extraSpecialArgs = {
        inherit inputs self;
        username = username;
        homeStateVersion = homeStateVersion;
      };
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      # This assumes that the home.nix file is in the machines/${hostname} directory.
      # ie. This only works for a single user.
      home-manager.users.${username} = import ./machines/${hostname}/home.nix;
      home-manager.sharedModules = [
        inputs.nixvim.homeManagerModules.nixvim
        ./modules/home
      ];
    };

    mkNixos = { system, username, hostname, systemStateVersion, homeStateVersion }: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs self;
        inherit username hostname systemStateVersion homeStateVersion;
      };
      modules = [
        inputs.sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        ./machines/${hostname}/configuration.nix
        (mkHomeManagerConfig { inherit username hostname homeStateVersion; })
        {
          nixpkgs.overlays = overlays;
        }
      ];
    };

    mkDarwin = { system, username, hostname, systemStateVersion, homeStateVersion }: darwin.lib.darwinSystem {
      inherit system;
      specialArgs = {
        inherit inputs self;
        inherit username hostname systemStateVersion homeStateVersion;
      };
      modules = [
        ./machines/${hostname}/configuration.nix
        inputs.sops-nix.darwinModules.sops
        home-manager.darwinModules.home-manager
        (mkHomeManagerConfig { inherit username hostname homeStateVersion; })
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

    mkHomeManagerSystem = { pkgs, username, homeStateVersion }: home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {
        inherit inputs;
        inherit username homeStateVersion;
      };
      modules = [
        ./machines/${username}/home.nix
        inputs.nixvim.homeManagerModules.nixvim
        ./modules/home
      ];
    };

  in
  {

    # Darwin - banana
    darwinConfigurations.banana = mkDarwin {
      system = systems.aarch64-darwin;
      username = "angel";
      hostname = "banana";
      systemStateVersion = 6;
      homeStateVersion = "25.05";
    };

    # Darwin - BENGKUI
    darwinConfigurations.BENGKUI = mkDarwin {
      system = systems.aarch64-darwin;
      username = "useradmin";
      hostname = "BENGKUI";
      systemStateVersion = 4;
      homeStateVersion = "24.05";
    };

    # NixOS - kiwi (NAS)
    nixosConfigurations.kiwi = mkNixos {
      system = systems.x86_64-linux;
      username = "angel";
      hostname = "kiwi";
      systemStateVersion = "24.11";
      homeStateVersion = "25.05";
    };

    # NixOS VM (nixos + home-manager)
    nixosConfigurations.nixos = mkNixos {
      system = systems.aarch64-linux;
      username = "angel";
      hostname = "nixos";
      systemStateVersion = "24.05";
      homeStateVersion = "24.05";
    };

    # Darwin - BASURA
    darwinConfigurations.BASURA = mkDarwin {
      system = systems.x86_64-darwin;
      username = "angel";
      hostname = "BASURA";
      systemStateVersion = 6;
      homeStateVersion = "24.11";
    };

    # Raspberry Pi (home-manager only)
    homeConfigurations.pi = mkHomeManagerSystem {
      pkgs = nixpkgs.legacyPackages.${systems.aarch64-linux};
      username = "pi";
      homeStateVersion = "24.05";
    };

    # Packages
    packages = nixpkgs.lib.genAttrs (builtins.attrNames systems) (system:
      nixpkgs.legacyPackages.${system}.callPackage ./packages {
        inherit inputs system;
        pkgs = nixpkgs.legacyPackages.${system};
      }
    );

    # Development shells
    devShells = nixpkgs.lib.genAttrs (builtins.attrNames systems) (system: {
      default = nixpkgs.legacyPackages.${system}.mkShell {

        packages = with nixpkgs.legacyPackages.${system}; [
          nh
          nix-output-monitor
          just
          # self.packages.${system}.scripts  # Your scripts available in dev shell
        ];

        # shellHook = ''
        #   exec zsh
        # '';
      };
    });

  };
}
