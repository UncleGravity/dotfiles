{
  inputs,
  lib,
  ...
}: let
  guestSystem = "aarch64-linux";
  hostSystem = "aarch64-darwin";

  mkMicrovm = {
    hostname,
    systemStateVersion,
  }:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs hostname;
        username = "angel";
      };
      modules = [
        inputs.microvm.nixosModules.microvm
        ../microvms/${hostname}.nix
        {
          nixpkgs = {
            hostPlatform = guestSystem;
            config.allowUnfree = true;
          };

          microvm.vmHostPackages = inputs.nixpkgs.legacyPackages.${hostSystem};
          system.stateVersion = systemStateVersion;
        }
      ];
    };

  configurations = {
    dev = mkMicrovm {
      hostname = "dev";
      systemStateVersion = "25.05";
    };

    small = mkMicrovm {
      hostname = "small";
      systemStateVersion = "25.05";
    };
  };
in {
  flake.nixosConfigurations = configurations;

  perSystem = {
    pkgs,
    system,
    ...
  }:
    lib.mkIf (system == hostSystem) {
      packages.vm = pkgs.callPackage ../microvms/cli.nix {
        vms =
          lib.mapAttrs (_: configuration: {
            runner = configuration.config.microvm.declaredRunner;
          })
          configurations;
      };
    };
}
