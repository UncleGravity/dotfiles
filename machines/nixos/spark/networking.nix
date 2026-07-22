{
  lib,
  node,
  sparkNodes,
  ...
}: let
  rail0 = "enp1s0f0np0";
  rail1 = "enP2p1s0f0np0";
  nodeId = toString node.id;

  fabricHosts =
    lib.foldlAttrs (
      hosts: hostname: peer:
        hosts
        // {
          "10.100.0.${toString peer.id}" = ["${hostname}-f0"];
          "10.100.1.${toString peer.id}" = ["${hostname}-f1"];
        }
    ) {}
    sparkNodes;
in {
  networking = {
    useDHCP = false;
    useNetworkd = true;
    hosts = fabricHosts;

    firewall = {
      enable = true;
      allowedTCPPorts = [22];
      trustedInterfaces = [rail0 rail1];
    };
  };

  systemd.network = {
    enable = true;

    links = {
      "10-fabric-0" = {
        matchConfig.OriginalName = rail0;
        linkConfig.MTUBytes = 9000;
      };
      "10-fabric-1" = {
        matchConfig.OriginalName = rail1;
        linkConfig.MTUBytes = 9000;
      };
    };

    networks = {
      "10-management" = {
        matchConfig.Name = "enP7s7";
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = false;
        };
        dhcpV4Config = {
          RouteMetric = 100;
          UseDNS = true;
        };
      };

      "20-fabric-0" = {
        matchConfig.Name = rail0;
        address = ["10.100.0.${nodeId}/24"];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = false;
          LinkLocalAddressing = "no";
        };
      };

      "20-fabric-1" = {
        matchConfig.Name = rail1;
        address = ["10.100.1.${nodeId}/24"];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = false;
          LinkLocalAddressing = "no";
        };
      };
    };
  };

  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };
}
