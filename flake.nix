{
  description = "Nixos config flake";

  inputs = {
    # https://nixos.org/nixpkgs/manual/
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      # https://nix-community.github.io/home-manager/options.xhtml
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      # https://daiderd.com/nix-darwin/manual/index.html
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    }; 

    # Use Zig nightly
    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    # Use Neovim nightly
    neovim-nightly = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        # flake-utils.follows = "flake-utils";
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
      nixosUser = "angel";
      nixosHostname = "nixos";
      workDarwinUser = "useradmin";
      workDarwinHostname = "BENGKUI";
      personalDarwinUser = "angel";
      personalDarwinHostname = "BASURA";
      piUser = "pi";
    in
    {
    # NixOS VM (nixos + home-manager)
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {
        inherit inputs;
        username = nixosUser;
        hostname = nixosHostname;
      };  
      modules = [
        ./nixos/configuration.nix # System Config (nixos)
        home-manager.nixosModules.home-manager
        {
          home-manager.extraSpecialArgs = { 
            inherit inputs;
            username = nixosUser;
          };
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${nixosUser} = import ./nixos/home.nix; # User Config (home-manager)
        }
      ];
    };

    # Darwin (macOS) - Work
    darwinConfigurations.${workDarwinHostname} = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = {
        inherit inputs;
        username = workDarwinUser;
        hostname = workDarwinHostname;
      };
      modules = [
        ./darwin/configuration.nix

        # Home-Manager
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit inputs;
            username = workDarwinUser;
          };
          home-manager.users.${workDarwinUser} = import ./darwin/home.nix;
        }

        # Nix-Homebrew
        nix-homebrew.darwinModules.nix-homebrew
        {
          # Configure nix-homebrew
          nix-homebrew = {
            enable = true;
            user = workDarwinUser;
            autoMigrate = true;
          };
        }
      ];
    };

    # Darwin (macOS) - Personal
    darwinConfigurations.${personalDarwinHostname} = darwin.lib.darwinSystem {
      system = "x86_64-darwin";
      specialArgs = {
        inherit inputs;
        username = personalDarwinUser;
        hostname = personalDarwinHostname;
      };
      modules = [
        # For now, reusing the existing ones:
        ./darwin/configuration.nix

        # Home-Manager
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit inputs;
            username = personalDarwinUser;
          };
          # For now, reusing the existing one:
          home-manager.users.${personalDarwinUser} = import ./darwin/home.nix;
        }

        # Nix-Homebrew
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            user = personalDarwinUser;
            autoMigrate = true;
          };
        }
      ];
    };

    # Raspberry Pi (home-manager only)
    homeConfigurations.${piUser} = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages."aarch64-linux";
      extraSpecialArgs = { 
        inherit inputs; 
        username = piUser;
      };
      modules = [ ./pi/home.nix ]; # User Config (home-manager)
    };

  };
}
