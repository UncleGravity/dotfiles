{ config, lib, username, ... }:
let
  cfg = config.my.docker;
in
{
  options.my.docker = {
    enable = lib.mkEnableOption "Docker with both root and rootless support";

    enableRootless = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable rootless Docker";
    };

    unprivilegedPortStart = lib.mkOption {
      type = lib.types.int;
      default = 80;
      description = "Lowest port number that rootless Docker can bind to";
    };
  };

  config = lib.mkIf cfg.enable {
    # Allow docker to access the network (to avoid port forwarding manually... I think)
    networking.firewall.trustedInterfaces = [ "docker0" ];

    # Root Docker
    virtualisation.docker.enable = true;
    users.users.${username}.extraGroups = [ "docker" ];

    # Rootless Docker
    virtualisation.docker.rootless = lib.mkIf cfg.enableRootless {
      enable = true;
      setSocketVariable = true; # will force docker to use rootless context
    };

    # Enable rootless docker service, it's not enabled by default
    systemd.user.services."docker".enable = cfg.enableRootless;

    # Rootless Docker won't have permission to use ports below 1024 by default
    boot.kernel.sysctl = lib.mkIf cfg.enableRootless {
      "net.ipv4.ip_unprivileged_port_start" = cfg.unprivilegedPortStart;
    };
  };
}
