{
  inputs,
  lib,
  ...
}: let
  sparkNodeSettings = import ../modules/clan/spark-cluster/inventory.nix;
  sparkNodeMembers = lib.mapAttrs (_: settings: {inherit settings;}) sparkNodeSettings;
in {
  imports = [inputs.clan-core.flakeModules.default];

  clan = {
    modules = {
      nas = ../modules/clan/nas;
      pangolin = ../modules/clan/pangolin;
      spark-cluster = ../modules/clan/spark-cluster;
    };

    meta = {
      name = "angelnet";
      domain = "angel.pizza";
    };

    specialArgs = {
      inherit inputs;
      username = "angel";
    };

    inventory.machines =
      {
        banana = {
          machineClass = "darwin";
          deploy.targetHost = "angel@banana";
        };
        kiwi.deploy.targetHost = "angel@kiwi";
        portal.deploy.targetHost = "angel@portal";
        sisyphus.deploy.targetHost = "angel@sisyphus";
      }
      // lib.mapAttrs (hostname: _: {
        deploy.targetHost = "angel@${hostname}";
      })
      sparkNodeSettings;

    inventory.instances = {
      sshd.roles.server.machines =
        {
          kiwi.settings.certificate.enable = false;
          portal.settings.certificate.enable = false;
          sisyphus.settings.certificate.enable = false;
        }
        // lib.mapAttrs (_: _: {settings.certificate.enable = false;}) sparkNodeSettings;

      pangolin = {
        module = {
          input = "self";
          name = "pangolin";
        };
        roles = {
          server.machines.portal.settings.letsEncryptEmail = "viera.tech@gmail.com";
          client.machines.kiwi = {};
        };
      };

      nas = {
        module = {
          input = "self";
          name = "nas";
        };
        roles = {
          server.machines.kiwi.settings = {
            address = "192.168.1.200";
            interface = "enp117s0";
            trustedNetworks = ["192.168.1.0/24"];
          };
          mount.machines =
            {
              sisyphus = {};
            }
            // lib.mapAttrs (_: _: {}) sparkNodeSettings;
        };
      };

      spark = {
        module = {
          input = "self";
          name = "spark-cluster";
        };
        roles = {
          node.machines = sparkNodeMembers;
          controller.machines.spark-01 = {};
          monitor.machines.kiwi.settings.sourceAddress = "192.168.1.200";
        };
      };
    };
  };
}
