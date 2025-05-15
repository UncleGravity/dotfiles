{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-darwin
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # Use nix-homebrew - Installs homebrew with nix.
    # Does not manage formulae, just installs homebrew.
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, darwin, nix-homebrew, ... }@inputs:
  let
    systems = {
      aarch64-linux = "aarch64-linux";
      aarch64-darwin = "aarch64-darwin";
      x86_64-linux = "x86_64-linux";
      x86_64-darwin = "x86_64-darwin";
    };

    mkHomeManagerConfig = { username, hostname }: {
      home-manager.extraSpecialArgs = {
        inherit inputs;
        username = username;
      };
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      # This assumes that the home.nix file is in the machines/${hostname} directory.
      # ie. This only works for a single user.
      home-manager.users.${username} = import ./machines/${hostname}/home.nix;
    };

    mkNixos = { system, username, hostname }: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs;
        inherit username hostname;
      };
      modules = [
        home-manager.nixosModules.home-manager
        ./machines/${hostname}/configuration.nix
        (mkHomeManagerConfig { inherit username hostname; })
      ];
    };

    mkDarwin = { system, username, hostname }: darwin.lib.darwinSystem {
      inherit system;
      specialArgs = {
        inherit inputs;
        inherit username hostname;
      };
      modules = [
        ./machines/${hostname}/configuration.nix
        home-manager.darwinModules.home-manager
        (mkHomeManagerConfig { inherit username hostname; })
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

    mkHomeManagerSystem = { pkgs, username   }: home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {
        inherit inputs;
        inherit username;
      };
      modules = [ ./machines/${username}/home.nix ];
    };

  in
  {
    # NixOS VM (nixos + home-manager)
    nixosConfigurations.nixos = mkNixos {
      system = systems.aarch64-linux;
      username = "angel";
      hostname = "nixos";
    };

    # Darwin - BENGKUI
    darwinConfigurations.BENGKUI = mkDarwin {
      system = systems.aarch64-darwin;
      username = "useradmin";
      hostname = "BENGKUI";
    };

    # Darwin - BASURA
    darwinConfigurations.BASURA = mkDarwin {
      system = systems.x86_64-darwin;
      username = "angel";
      hostname = "BASURA";
    };

    # Raspberry Pi (home-manager only)
    homeConfigurations.pi = mkHomeManagerSystem {
      pkgs = nixpkgs.legacyPackages."aarch64-linux";
      username = "pi";
    };

  };
}
