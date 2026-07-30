{
  config,
  lib,
  username,
  ...
}: let
  lanInterface = "enp117s0";
  nasUid = 1000;
  nasGid = 100;
  clients = [
    "192.168.1.31" # DGX Spark 01
    "192.168.1.32" # DGX Spark 02
    "192.168.1.33" # DGX Spark 03
    "192.168.1.34" # DGX Spark 04
    "192.168.1.139" # Sisyphus
  ];
  exportOptions = [
    "rw"
    "sync"
    "all_squash"
    "anonuid=${toString nasUid}"
    "anongid=${toString nasGid}"
    "fsid=0"
    "crossmnt"
    "no_subtree_check"
  ];
in {
  assertions = [
    {
      assertion =
        config.users.users.${username}.uid
        == nasUid
        && config.users.groups.users.gid == nasGid;
      message = "Kiwi's NFS export expects ${username} to use UID ${toString nasUid} and the users group to use GID ${toString nasGid}";
    }
  ];

  services.nfs = {
    server = {
      enable = true;
      exports."/nas" = lib.genAttrs clients (_: exportOptions);
    };

    settings.nfsd = {
      vers3 = false;
      vers4 = true;
    };
  };

  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts = [2049];
}
