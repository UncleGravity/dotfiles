{
  config,
  lib,
  pkgs,
  ...
}: let
  domain = "grafana.angel.pizza";
  authDomain = "auth.angel.pizza";
  address = "127.0.0.1";
  grafanaPort = 3131;
  prometheusPort = 9090;
  nodeExporterPort = 9100;
  sparkCluster = config.my.sparkCluster;
  mkSparkStaticConfigs = port:
    lib.mapAttrsToList (hostname: peer: {
      targets = ["${peer.managementAddress}:${toString port}"];
      labels = {
        cluster = "spark";
        node = hostname;
      };
    })
    sparkCluster.nodes;
  resticExporterPorts = {
    b2 = 9753;
    t7 = 9754;
  };
  dashboardDir = "/etc/grafana/dashboards";

  mkResticExporter = {
    environmentFile ? null,
    name,
    passwordFile,
    port,
    repository ? null,
    repositoryFile ? null,
    requiredMounts ? [],
  }: let
    repositorySetup =
      if repositoryFile != null
      then ''export RESTIC_REPOSITORY="$(<"$CREDENTIALS_DIRECTORY/RESTIC_REPOSITORY")"''
      else ''export RESTIC_REPOSITORY=${lib.escapeShellArg repository}'';
  in
    assert (repository == null) != (repositoryFile == null); {
      description = "Prometheus exporter for the ${name} Restic repository";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      unitConfig.RequiresMountsFor = requiredMounts;

      environment = {
        EXIT_ON_ERROR = "true";
        LISTEN_ADDRESS = address;
        LISTEN_PORT = toString port;
        REFRESH_INTERVAL = "129600";
        RESTIC_CACHE_DIR = "/var/cache/restic-exporter-${name}";
      };

      script = ''
        ${repositorySetup}
        export RESTIC_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/RESTIC_PASSWORD"
        exec ${lib.getExe pkgs.prometheus-restic-exporter}
      '';

      serviceConfig =
        {
          CacheDirectory = "restic-exporter-${name}";
          CacheDirectoryMode = "0700";
          DynamicUser = true;
          LoadCredential =
            ["RESTIC_PASSWORD:${passwordFile}"]
            ++ lib.optional (repositoryFile != null) "RESTIC_REPOSITORY:${repositoryFile}";
          Restart = "on-failure";
          RestartSec = "6h";
          UMask = "0077";

          CapabilityBoundingSet = "";
          DeviceAllow = "";
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectSystem = "strict";
          RemoveIPC = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
        }
        // lib.optionalAttrs (environmentFile != null) {
          EnvironmentFile = environmentFile;
        };
    };

  mkResticExporterRefresh = name: {
    description = "Refresh ${name} Restic exporter metrics";
    serviceConfig = {
      Type = "oneshot";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
    };
    script = ''
      ${pkgs.systemd}/bin/systemctl restart prometheus-restic-exporter-${name}.service
    '';
  };
in {
  clan.core.vars.generators.grafana-secret-key = {
    prompts.secret-key = {
      description = "Grafana secret key";
      type = "hidden";
      persist = true;
    };
    files.secret-key = {
      owner = "grafana";
      group = "grafana";
      mode = "0400";
      restartUnits = ["grafana.service"];
    };
    script = ''
      if [[ ! -s "$out/secret-key" ]]; then
        echo "Grafana secret key must not be empty" >&2
        exit 1
      fi
      originalSize="$(wc -c < "$out/secret-key")"
      singleLineSize="$(tr -d '\r\n' < "$out/secret-key" | wc -c)"
      if [[ "$originalSize" -ne "$singleLineSize" ]]; then
        echo "Grafana secret key must be a single line" >&2
        exit 1
      fi
    '';
  };

  services = {
    grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = address;
          http_port = grafanaPort;
          inherit domain;
          root_url = "https://${domain}/";
          enable_gzip = true;
        };

        users = {
          allow_sign_up = false;
          allow_org_create = false;
          auto_assign_org = true;
          auto_assign_org_role = "Viewer";
        };

        security = {
          secret_key = "$__file{${config.clan.core.vars.generators.grafana-secret-key.files.secret-key.path}}";
          disable_initial_admin_creation = true;
          disable_gravatar = true;
          cookie_secure = true;
          strict_transport_security = true;
          strict_transport_security_max_age_seconds = 31536000;
        };

        auth.disable_login_form = true;
        "auth.basic".enabled = false;
        "auth.generic_oauth" = {
          enabled = true;
          name = "TinyAuth";
          allow_sign_up = true;
          auto_login = true;
          client_id = "686c07de-8601-48af-8ac1-59c2a05856c0";
          client_secret = "$__file{${config.clan.core.vars.generators.tinyauth-oidc-grafana.files.grafana-client-secret.path}}";
          scopes = "openid profile email";
          auth_url = "https://${authDomain}/authorize";
          token_url = "https://${authDomain}/api/oidc/token";
          api_url = "https://${authDomain}/api/oidc/userinfo";
          use_pkce = true;
          use_refresh_token = true;
          validate_id_token = true;
          jwk_set_url = "https://${authDomain}/.well-known/jwks.json";
          login_attribute_path = "preferred_username";
          name_attribute_path = "name";
          email_attribute_path = "email";
          role_attribute_path = "preferred_username == 'angel' && 'GrafanaAdmin' || 'Viewer'";
          role_attribute_strict = true;
          allow_assign_grafana_admin = true;
        };

        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
          check_for_plugin_updates = false;
          feedback_links_enabled = false;
        };
        news.news_feed_enabled = false;
        plugins.preinstall_disabled = true;
        snapshots.external_enabled = false;
      };

      provision = {
        enable = true;
        datasources.settings = {
          prune = true;
          datasources = [
            {
              name = "Prometheus";
              uid = "prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://${address}:${toString prometheusPort}";
              isDefault = true;
              editable = false;
              jsonData.timeInterval = "10s";
            }
          ];
        };
        dashboards.settings.providers = [
          {
            name = "system";
            orgId = 1;
            folder = "System Monitoring";
            type = "file";
            disableDeletion = false;
            allowUiUpdates = false;
            updateIntervalSeconds = 60;
            options = {
              path = dashboardDir;
              foldersFromFilesStructure = false;
            };
          }
        ];
      };
    };

    newt.blueprint.proxy-resources.grafana = {
      name = "Grafana";
      protocol = "http";
      full-domain = domain;
      auth.sso-enabled = false;
      targets = [
        {
          hostname = address;
          method = "http";
          port = grafanaPort;
          healthcheck = {
            enabled = true;
            hostname = address;
            method = "GET";
            port = grafanaPort;
            path = "/api/health";
            scheme = "http";
            status = 200;
          };
        }
      ];
    };

    prometheus = {
      enable = true;
      listenAddress = address;
      port = prometheusPort;
      retentionTime = "180d";
      globalConfig.scrape_interval = "10s";
      exporters.node = {
        enable = true;
        listenAddress = address;
        port = nodeExporterPort;
        enabledCollectors = [
          "systemd"
          "processes"
        ];
      };
      scrapeConfigs = [
        {
          job_name = "kiwi";
          static_configs = [
            {
              targets = ["${address}:${toString nodeExporterPort}"];
            }
          ];
        }
        {
          job_name = "spark-node";
          scrape_interval = "5s";
          scrape_timeout = "4s";
          static_configs = mkSparkStaticConfigs sparkCluster.monitor.nodeExporterPort;
        }
        {
          job_name = "spark-gpu";
          scrape_interval = "5s";
          scrape_timeout = "4s";
          static_configs = mkSparkStaticConfigs sparkCluster.monitor.gpuExporterPort;
        }
        {
          job_name = "restic-b2";
          scrape_interval = "1m";
          static_configs = [
            {
              targets = ["${address}:${toString resticExporterPorts.b2}"];
              labels.repository = "B2";
            }
          ];
        }
        {
          job_name = "restic-t7";
          scrape_interval = "1m";
          static_configs = [
            {
              targets = ["${address}:${toString resticExporterPorts.t7}"];
              labels.repository = "T7";
            }
          ];
        }
      ];
    };
  };

  systemd.services = {
    prometheus-restic-exporter-b2 = mkResticExporter {
      name = "b2";
      port = resticExporterPorts.b2;
      environmentFile = config.sops.secrets."backup/b2.env".path;
      repositoryFile = config.sops.secrets."backup/b2/restic/repo".path;
      passwordFile = config.sops.secrets."backup/b2/restic/password".path;
    };

    prometheus-restic-exporter-t7 = mkResticExporter {
      name = "t7";
      port = resticExporterPorts.t7;
      repository = "/mnt/t7/restic";
      passwordFile = config.sops.secrets."backup/t7-password".path;
      requiredMounts = ["/mnt/t7"];
    };

    refresh-restic-exporter-b2 = mkResticExporterRefresh "b2";
    refresh-restic-exporter-t7 = mkResticExporterRefresh "t7";

    restic-backups-b2.unitConfig.OnSuccess = lib.mkAfter ["refresh-restic-exporter-b2.service"];
    restic-backups-t7.unitConfig.OnSuccess = lib.mkAfter ["refresh-restic-exporter-t7.service"];
  };

  environment.etc."grafana/dashboards/restic-backups.json".source = ./dashboards/restic-backups.json;
  environment.etc."grafana/dashboards/spark-cluster-overview.json".source = ./dashboards/spark-cluster-overview.json;
  environment.etc."grafana/dashboards/spark-cluster.json".source = ./dashboards/spark-cluster.json;
  environment.etc."grafana/dashboards/system-overview.json".source = ./dashboards/system-overview.json;
}
