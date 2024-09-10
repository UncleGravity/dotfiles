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
    

    # Use yazi nightly
    yazi = {
      url = "github:sxyazi/yazi";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    # Use Zig nightly
    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

  };

  outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs:
  let
      nixosUser = "angel";
      nixosHostname = "nixos";
      darwinUser = "useradmin";
      darwinHostname = "BENGKUI";
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

    # Darwin (macOS)
    darwinConfigurations.${darwinHostname} = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = {
        inherit inputs;
        username = darwinUser;
        hostname = darwinHostname;
      };
      modules = [
        ./darwin/configuration.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit inputs;
            username = darwinUser;
          };
          home-manager.users.${darwinUser} = import ./darwin/home.nix;
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