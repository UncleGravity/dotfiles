{
  lib,
  node,
  sparkNodes,
  ...
}: let
  managementInterface = "mgmt0";
  fabric0Interface = "fabric0";
  fabric1Interface = "fabric1";
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
      trustedInterfaces = [fabric0Interface fabric1Interface];
    };
  };

  systemd.network = {
    enable = true;

    links = {
      "10-management" = {
        matchConfig.PermanentMACAddress = node.managementMac;
        linkConfig.Name = managementInterface;
      };
      "10-fabric-0" = {
        matchConfig.Path = "pci-0000:01:00.0";
        linkConfig = {
          Name = fabric0Interface;
          MTUBytes = 9000;
        };
      };
      "10-fabric-1" = {
        matchConfig.Path = "pci-0002:01:00.0";
        linkConfig = {
          Name = fabric1Interface;
          MTUBytes = 9000;
        };
      };
    };

    networks = {
      "10-management" = {
        matchConfig.Name = managementInterface;
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
        matchConfig.Name = fabric0Interface;
        address = ["10.100.0.${nodeId}/24"];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = false;
          LinkLocalAddressing = "no";
        };
      };

      "20-fabric-1" = {
        matchConfig.Name = fabric1Interface;
        address = ["10.100.1.${nodeId}/24"];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = false;
          LinkLocalAddressing = "no";
        };
      };
    };
  };

  # mDNS
  services.avahi = {
    enable = true;
    openFirewall = false;
    allowInterfaces = [managementInterface];
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  networking.firewall.interfaces.${managementInterface}.allowedUDPPorts = [5353]; # mDNS

  assertions = [
    {
      assertion = node.id >= 1 && node.id <= 254;
      message = "Spark node IDs must fit in the two /24 fabric networks";
    }
  ];
}
