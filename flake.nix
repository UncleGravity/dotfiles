{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-darwin
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Installs homebrew with nix.
    # Does not manage formulae, just installs homebrew.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Zig nightly
    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    neovim-nightly = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, darwin, nix-homebrew, sops-nix, ... }@inputs:
  let
    systems = {
      aarch64-linux = "aarch64-linux";
      aarch64-darwin = "aarch64-darwin";
      x86_64-linux = "x86_64-linux";
      x86_64-darwin = "x86_64-darwin";
    };

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
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            user = username; # Assuming username is the same as nix-homebrew user
            autoMigrate = true;
          };
        }
      ];
    };

    mkHomeManagerSystem = { pkgs, username, homeStateVersion }: home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {
        inherit inputs;
        inherit username homeStateVersion;
      };
      modules = [ ./machines/${username}/home.nix ];
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

  };
}
