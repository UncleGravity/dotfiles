{
  inputs,
  self,
  ...
}: {
  imports = [inputs.clan-core.flakeModules.default];

  clan = {
    # Avoid autoincluding the current machines/{nixos,darwin} grouping directories.
    directory = "${inputs.self}/flake-modules";
    meta = {
      name = "angelnet";
      domain = "angel.pizza";
    };

    specialArgs = {
      inherit inputs;
      username = "angel";
    };

    inventory.machines.portal.deploy.targetHost = "angel@portal";

    machines.portal = {
      _module.args.hostname = "portal";

      imports = [
        ../modules/nixos
        self.nixosModules.inference
        inputs.home-manager.nixosModules.home-manager
        ../machines/nixos/portal/configuration.nix
      ];

      clan.core.enableRecommendedDefaults = false;

      # Preserve the pre-Clan values against unconditional Clan ZFS defaults.
      networking.hostId = null;
      boot.zfs.forceImportRoot = true;

      nixpkgs = {
        hostPlatform = "x86_64-linux";
        config.allowUnfree = true;
      };

      system = {
        stateVersion = "26.05";
        configurationRevision = self.rev or self.dirtyRev or self.narHash;
      };

      home-manager = {
        extraSpecialArgs = {
          inherit inputs;
          username = "angel";
        };
        sharedModules = [../modules/home];
        useGlobalPkgs = true;
        useUserPackages = true;
        users.angel = {
          imports = [../machines/nixos/portal/home.nix];
          home.stateVersion = "26.05";
        };
      };
    };
  };
}
