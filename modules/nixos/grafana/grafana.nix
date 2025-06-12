{ pkgs, config, ... }:

let
  # Suppose we store our dashboards JSON under ./grafana/dashboards/*.json
  dashboardDir = "/etc/nixos/grafana/dashboards";
in
{

  sops.secrets."grafana/password" = {
    mode = "0600";
    owner = "grafana";
    group = "grafana";
  };

  services.grafana = {
    enable = true;

    # Basic server settings:
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3131;
        domain     = "grafana.angel.pizza";
      };

      # Security / user management:
      users = {
        allow_sign_up   = false;  # no one can self-register
        auto_assign_org = true;   # new orgs not created per user
      };

      security = {
        admin_user     = "admin";
        admin_password = "$__file{${config.sops.secrets."grafana/password".path}}";
        disable_gravatar = true;
        cookie_secure    = true;
      };

      analytics.reporting_enabled = false;  # opt-out telemetry
    };

    # # Plugins:
    # declarativePlugins = with pkgs.grafanaPlugins; [
    #   grafana-admin-panel
    #   grafana-clock-panel
    #   simple-json-datasource
    # ];

    # Provisioning:
    provision = {
      enable = true;

      # Data sources: "prom" for Prometheus
      datasources = {
        settings = {
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
            }
          ];
        };
      };

      # Dashboards: pick up all JSON under dashboardDir
      # dashboards = {
      #   settings = {
      #     providers = [
      #       {
      #         name                = "default";
      #         orgId               = 1;
      #         folder              = "Cluster Metrics";
      #         type                = "file";
      #         disableDeletion     = false;
      #         allowUiUpdates      = true;
      #         updateIntervalSeconds = 60;
      #         options = {
      #           path = dashboardDir;
      #           foldersFromFilesStructure = false;
      #         };
      #       }
      #     ];
      #   };
      # };
      
    };
  };

  services.prometheus = {
    enable = true;
    port = 9090;
    globalConfig.scrape_interval = "10s"; # "1m"
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" "processes"];
      };
    };
    scrapeConfigs = [
      {
        job_name = "kiwi";
        static_configs = [{
          targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
        }];
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [ 3131 ]; # Caddy needs this to access the web interface
}
