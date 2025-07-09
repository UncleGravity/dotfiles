{ pkgs, config, ... }:

let
  # Store our dashboards JSON under ./dashboards/*.json relative to this file
  dashboardDir = "/etc/grafana/dashboards";
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
        domain = "grafana.angel.pizza";
      };

      # Security / user management:
      users = {
        allow_sign_up = false; # no one can self-register
        auto_assign_org = true; # new orgs not created per user
      };

      security = {
        admin_user = "admin";
        admin_password = "$__file{${config.sops.secrets."grafana/password".path}}";
        disable_gravatar = true;
        cookie_secure = true;
      };

      analytics.reporting_enabled = false; # opt-out telemetry
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
      dashboards = {
        settings = {
          providers = [
            {
              name = "default";
              orgId = 1;
              folder = "System Monitoring";
              type = "file";
              disableDeletion = false;
              allowUiUpdates = true;
              updateIntervalSeconds = 60;
              options = {
                path = dashboardDir;
                foldersFromFilesStructure = false;
              };
            }
          ];
        };
      };
    };
  };

  services.prometheus = {
    enable = true;
    port = 9090;
    globalConfig.scrape_interval = "10s"; # "1m"
    exporters = {
      node = {
        enable = true;
        enabledCollectors = ["systemd" "processes"];
      };
    };
    scrapeConfigs = [
      {
        job_name = "kiwi";
        static_configs = [
          {
            targets = ["127.0.0.1:${toString config.services.prometheus.exporters.node.port}"];
          }
        ];
      }
      {
        job_name = "telegraf";
        static_configs = [
          {
            targets = ["127.0.0.1:9273"]; # Telegraf Prometheus output port
          }
        ];
      }
    ];
  };

  # Telegraf configuration for system monitoring
  services.telegraf = {
    enable = true;

    extraConfig = {
      agent = {
        interval = "10s";
        round_interval = true;
        metric_batch_size = 1000;
        metric_buffer_limit = 10000;
        collection_jitter = "0s";
        flush_interval = "10s";
        flush_jitter = "0s";
        precision = "";
        hostname = "";
        omit_hostname = false;
      };

      # Prometheus output
      outputs.prometheus_client = {
        listen = ":9273";
        metric_version = 2;
      };

      # Input plugins for system monitoring
      inputs = {
        # CPU metrics
        cpu = {
          percpu = true;
          totalcpu = true;
          collect_cpu_time = false;
          report_active = false;
        };

        # Memory metrics
        mem = {};

        # Disk metrics
        disk = {
          ignore_fs = ["tmpfs" "devtmpfs" "devfs" "iso9660" "overlay" "aufs" "squashfs"];
        };

        # Disk I/O metrics
        diskio = {};

        # Network metrics
        net = {
          ignore_protocol_stats = false;
        };

        # System load
        system = {};

        # Process metrics
        processes = {};

        # Kernel metrics
        kernel = {};
      };
    };
  };

  networking.firewall.allowedTCPPorts = [3131 9273]; # Caddy needs this to access the web interface, and Telegraf Prometheus endpoint
}
