{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    {
    # NixOS VM (nixos + home-manager)
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit inputs;};  
      modules = [
        ./nixos/configuration.nix # System Config (nixos)
        home-manager.nixosModules.home-manager
        {
          home-manager.extraSpecialArgs = { 
            inherit inputs;
            username = "angel";
          };
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.angel = import ./nixos/home.nix; # User Config (home-manager)
        }
      ];
    };

    # Raspberry Pi (home-manager only)
    homeConfigurations.pi =home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages."aarch64-linux";
      extraSpecialArgs = { 
        inherit inputs; 
        username = "pi";
      };
      modules = [ ./pi/home.nix ]; # User Config (home-manager)
    };

  };
}