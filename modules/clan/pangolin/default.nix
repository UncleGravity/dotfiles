{lib, ...}: let
  serverGenerator = "pangolin-server-pangolin";
  cloudflareGenerator = "pangolin-cloudflare-pangolin";
  newtGenerator = "newt-pangolin";
in {
  _class = "clan.service";

  manifest = {
    name = "pangolin";
    description = "Pangolin server and Newt clients";
    readme = "Configures one Pangolin server and its associated Newt clients.";
    categories = ["Network"];
    constraints = {
      maxInstances = 1;
      roles = {
        server = {
          minMachines = 1;
          maxMachines = 1;
        };
        client.minMachines = 1;
      };
    };
  };

  roles.server = {
    description = "Hosts Pangolin, Gerbil, and Traefik.";

    interface = {
      config,
      lib,
      meta,
      ...
    }: {
      options = {
        baseDomain = lib.mkOption {
          type = lib.types.str;
          default = meta.domain;
          description = "Base domain served by Pangolin.";
        };
        dashboardDomain = lib.mkOption {
          type = lib.types.str;
          default = "pangolin.${config.baseDomain}";
          description = "Public Pangolin dashboard domain.";
        };
        letsEncryptEmail = lib.mkOption {
          type = lib.types.str;
          description = "Email used for Let's Encrypt.";
        };
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open Pangolin's public firewall ports.";
        };
      };
    };

    perInstance = {settings, ...}: {
      nixosModule = {
        config,
        pkgs,
        ...
      }: {
        clan.core.vars.generators.${serverGenerator} = {
          share = true;
          files.environment = {
            secret = true;
            restartUnits = [
              "pangolin.service"
              "gerbil.service"
            ];
          };
          runtimeInputs = [pkgs.openssl];
          script = ''
            {
              printf 'SERVER_SECRET='
              openssl rand -hex 32
            } > "$out/environment"
          '';
        };

        clan.core.vars.generators.${cloudflareGenerator} = {
          share = true;
          prompts.dns-token = {
            description = "Cloudflare DNS API token";
            type = "hidden";
            persist = false;
          };
          files.environment = {
            secret = true;
            restartUnits = ["traefik.service"];
          };
          script = ''
            token="$(cat "$prompts/dns-token")"
            if [[ -z "$token" || "$token" == *$'\n'* ]]; then
              echo "Cloudflare DNS token must be a non-empty single line" >&2
              exit 1
            fi

            printf 'CF_DNS_API_TOKEN=%s\n' "$token" > "$out/environment"
          '';
        };

        services.pangolin = {
          enable = true;
          inherit
            (settings)
            baseDomain
            dashboardDomain
            letsEncryptEmail
            openFirewall
            ;
          dnsProvider = "cloudflare";
          environmentFile = config.clan.core.vars.generators.${serverGenerator}.files.environment.path;
          settings.domains.domain1.prefer_wildcard_cert = true;
        };

        services.traefik = {
          environmentFiles = [
            config.clan.core.vars.generators.${cloudflareGenerator}.files.environment.path
          ];
          staticConfigOptions = {
            log.level = "INFO";
            certificatesResolvers.letsencrypt.acme.dnsChallenge = {
              resolvers = [
                "1.1.1.1:53"
                "1.0.0.1:53"
              ];
              propagation.disableChecks = true;
            };
          };
        };

        systemd.services.traefik.environment.LEGO_DISABLE_CNAME_SUPPORT = "true";
      };
    };
  };

  roles.client = {
    description = "Connects local workloads to Pangolin through Newt.";

    perInstance = {
      instanceName,
      roles,
      ...
    }: let
      serverNames = lib.attrNames (roles.server.machines or {});
      serverSettings =
        if lib.length serverNames == 1
        then roles.server.machines.${lib.head serverNames}.settings
        else throw "Pangolin instance '${instanceName}' requires exactly one server";
    in {
      nixosModule = {config, ...}: {
        clan.core.vars.generators.${newtGenerator} = {
          prompts = {
            newt-id = {
              description = "Newt client ID";
              type = "hidden";
              persist = false;
            };
            newt-secret = {
              description = "Newt client secret";
              type = "hidden";
              persist = false;
            };
          };
          files.environment = {
            secret = true;
            restartUnits = ["newt.service"];
          };
          script = ''
            id="$(cat "$prompts/newt-id")"
            secret="$(cat "$prompts/newt-secret")"
            if [[ -z "$id" || "$id" == *$'\n'* || -z "$secret" || "$secret" == *$'\n'* ]]; then
              echo "Newt credentials must be non-empty single lines" >&2
              exit 1
            fi

            {
              printf 'NEWT_ID=%s\n' "$id"
              printf 'NEWT_SECRET=%s\n' "$secret"
            } > "$out/environment"
          '';
        };

        services.newt = {
          enable = true;
          settings.endpoint = "https://${serverSettings.dashboardDomain}";
          environmentFile = config.clan.core.vars.generators.${newtGenerator}.files.environment.path;
        };
      };
    };
  };
}
