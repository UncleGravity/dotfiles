{lib, ...}: let
  automountOptions = [
    "proto=tcp"
    "_netdev"
    "nofail"
    "x-systemd.automount"
    "x-systemd.idle-timeout=10min"
    "x-systemd.mount-timeout=15s"
  ];
in {
  _class = "clan.service";

  manifest = {
    name = "nas";
    description = "Kiwi NFS server and managed fleet mounts";
    readme = "Exports Kiwi's shared dataset to trusted networks and configures mounts on managed machines.";
    categories = ["System"];
    constraints = {
      maxInstances = 1;
      roles = {
        server = {
          minMachines = 1;
          maxMachines = 1;
        };
        mount.minMachines = 1;
      };
    };
  };

  roles.server = {
    description = "Exports Kiwi's shared dataset over NFSv4.";

    interface = {lib, ...}: {
      options = {
        address = lib.mkOption {
          type = lib.types.str;
          description = "Address used by NFS clients.";
        };
        interface = lib.mkOption {
          type = lib.types.str;
          description = "Network interface on which NFS is available.";
        };
        trustedNetworks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "Networks authorized to mount the NFS export.";
        };
      };
    };

    perInstance = {
      instanceName,
      settings,
      ...
    }: {
      nixosModule = {
        config,
        username,
        ...
      }: let
        shareUid = 1000;
        shareGid = 100;
        exportOptions = [
          "rw"
          "sync"
          "all_squash"
          "anonuid=${toString shareUid}"
          "anongid=${toString shareGid}"
          "fsid=0"
          "no_subtree_check"
        ];
      in {
        assertions = [
          {
            assertion = settings.trustedNetworks != [];
            message = "NAS instance '${instanceName}' requires at least one trusted network";
          }
          {
            assertion =
              config.users.users.${username}.uid
              == shareUid
              && config.users.groups.users.gid == shareGid;
            message = "NAS instance '${instanceName}' expects ${username} to use UID ${toString shareUid} and the users group to use GID ${toString shareGid}";
          }
        ];

        services.nfs = {
          server = {
            enable = true;
            exports."/srv/share" = lib.genAttrs settings.trustedNetworks (_: exportOptions);
          };
          settings.nfsd = {
            vers3 = false;
            vers4 = true;
          };
        };

        networking.firewall.interfaces.${settings.interface}.allowedTCPPorts = [2049];

        systemd.services.nfs-server.unitConfig.RequiresMountsFor = ["/srv/share"];
      };
    };
  };

  roles.mount = {
    description = "Configures an automount for Kiwi's NFS export.";

    perInstance = {
      instanceName,
      roles,
      ...
    }: let
      serverNames = lib.attrNames (roles.server.machines or {});
      server =
        if lib.length serverNames == 1
        then roles.server.machines.${lib.head serverNames}
        else throw "NAS instance '${instanceName}' requires exactly one server";
    in {
      nixosModule = _: {
        fileSystems."/mnt/nas/kiwi" = {
          device = "${server.settings.address}:/";
          fsType = "nfs";
          options = ["nfsvers=4.2"] ++ automountOptions;
        };
      };
    };
  };
}
