{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.tailscale;
in {
  options.my.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN with exit node and subnet routing";

    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["192.168.1.0/24"];
      description = "Subnets to advertise to the tailnet";
    };

    enableExitNode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to advertise this machine as an exit node";
    };
  };

  config = lib.mkIf cfg.enable {
    clan.core.vars.generators.tailscale = {
      prompts.authkey = {
        description = "Tailscale enrollment key";
        type = "hidden";
        persist = true;
      };

      files.authkey = {
        mode = "0600";
      };

      script = ''
        authkey="$(cat "$prompts/authkey")"
        if [[ -z "$authkey" || "$authkey" == *$'\n'* ]]; then
          echo "Tailscale enrollment key must be a non-empty single line" >&2
          exit 1
        fi

        printf '%s' "$authkey" > "$out/authkey"
      '';
    };

    environment.systemPackages = [pkgs.tailscale];
    networking.firewall.trustedInterfaces = ["tailscale0"];
    services.resolved.enable = true; # Avoid DNS issues

    services.tailscale = {
      enable = true;
      authKeyFile = config.clan.core.vars.generators.tailscale.files.authkey.path;
      openFirewall = true; # allow the Tailscale UDP port through the firewall
      useRoutingFeatures = "both"; # enable subnet-router & exit-node roles
      extraUpFlags =
        [
          "--reset" # reset unspecified settings to default values.
        ]
        ++ lib.optionals cfg.enableExitNode [
          "--advertise-exit-node"
        ];
      extraSetFlags = lib.optionals (cfg.advertiseRoutes != []) [
        "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
      ];
    };
  };
}
