{
  config,
  lib,
  pkgs,
  ...
}: let
  domain = "auth.angel.pizza";
  port = 3000;
  statePath = "/var/lib/tinyauth";
  secretNames = [
    "tinyauth/oidc/dawarich-client-secret"
    "tinyauth/oidc/open-webui-client-secret"
    "tinyauth/oidc/pangolin-client-secret"
    "tinyauth/oidc/grafana-client-secret"
  ];
in {
  clan.core.vars.generators.tinyauth-users = {
    prompts.users = {
      description = "TinyAuth users file";
      type = "multiline-hidden";
      persist = true;
    };
    files.users = {
      owner = "tinyauth";
      group = "tinyauth";
      mode = "0400";
      restartUnits = ["tinyauth.service"];
    };
    runtimeInputs = [pkgs.gawk];
    script = ''
      awk '
        BEGIN {
          records = 0
          invalid = 0
        }
        {
          line = $0
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
          if (line == "") next

          count = split(line, parts, ":")
          if (count < 2 || count > 3) {
            invalid = 1
            next
          }

          for (i = 1; i <= count; i++) {
            field = parts[i]
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
            if (field == "") invalid = 1
            parts[i] = field
          }

          username = parts[1]
          hash = parts[2]
          gsub(/\$\$/, "$", hash)
          if (seen[username]++) invalid = 1
          if (hash !~ /^\$2[aby]\$(0[4-9]|[12][0-9]|3[01])\$[.\/A-Za-z0-9]{53}$/) invalid = 1
          records++
        }
        END {
          if (records == 0 || invalid) {
            print "TinyAuth users file must contain unique username:bcrypt[:totp] records" > "/dev/stderr"
            exit 1
          }
        }
      ' "$out/users"
    '';
  };

  sops.secrets = lib.genAttrs secretNames (_: {
    sopsFile = ../secrets/secrets.yaml;
    owner = "tinyauth";
    group = "tinyauth";
    mode = "0400";
    restartUnits = ["tinyauth.service"];
  });

  services = {
    tinyauth = {
      enable = true;
      settings = {
        APPURL = "https://${domain}";
        LABELPROVIDER = "none";
        RESOURCES_ENABLED = false;

        SERVER_ADDRESS = "127.0.0.1";
        SERVER_PORT = port;

        AUTH_SECURECOOKIE = true;
        AUTH_SUBDOMAINSENABLED = false;
        AUTH_TRUSTEDPROXIES = "127.0.0.1/32";
        AUTH_USERSFILE = config.clan.core.vars.generators.tinyauth-users.files.users.path;
        AUTH_USERATTRIBUTES_ANGEL_NAME = "Angel";
        AUTH_USERATTRIBUTES_ANGEL_EMAIL = "viera.tech@gmail.com";
        AUTH_USERATTRIBUTES_ANGEL_LOCALE = "en-US";
        AUTH_USERATTRIBUTES_ANGEL_ZONEINFO = "America/Los_Angeles";
        AUTH_USERATTRIBUTES_JAY_NAME = "Jay";
        AUTH_USERATTRIBUTES_JAY_EMAIL = "me@chenjay.com";

        OIDC_PRIVATEKEYPATH = "${statePath}/oidc/key.pem";
        OIDC_PUBLICKEYPATH = "${statePath}/oidc/key.pub";
        OIDC_CLIENTS_OPENWEBUI_CLIENTID = "57d07a26-42eb-46fc-92a8-b94ec7a7ff40";
        OIDC_CLIENTS_OPENWEBUI_CLIENTSECRETFILE = config.sops.secrets."tinyauth/oidc/open-webui-client-secret".path;
        OIDC_CLIENTS_OPENWEBUI_NAME = "Open WebUI";
        OIDC_CLIENTS_OPENWEBUI_TRUSTEDREDIRECTURIS = "https://ai.angel.pizza/oauth/oidc/callback";
        OIDC_CLIENTS_DAWARICH_CLIENTID = "19ca6a2e-1dd9-4b02-b4f4-3b8520cd878e";
        OIDC_CLIENTS_DAWARICH_CLIENTSECRETFILE = config.sops.secrets."tinyauth/oidc/dawarich-client-secret".path;
        OIDC_CLIENTS_DAWARICH_NAME = "Dawarich";
        OIDC_CLIENTS_DAWARICH_TRUSTEDREDIRECTURIS = "https://dawarich.angel.pizza/users/auth/openid_connect/callback";
        OIDC_CLIENTS_PANGOLIN_CLIENTID = "a2ceaf54-0329-422e-81f8-ef801a87ac1d";
        OIDC_CLIENTS_PANGOLIN_CLIENTSECRETFILE = config.sops.secrets."tinyauth/oidc/pangolin-client-secret".path;
        OIDC_CLIENTS_PANGOLIN_NAME = "Pangolin";
        OIDC_CLIENTS_PANGOLIN_TRUSTEDREDIRECTURIS = "https://pangolin.angel.pizza/auth/idp/1/oidc/callback";
        OIDC_CLIENTS_GRAFANA_CLIENTID = "686c07de-8601-48af-8ac1-59c2a05856c0";
        OIDC_CLIENTS_GRAFANA_CLIENTSECRETFILE = config.sops.secrets."tinyauth/oidc/grafana-client-secret".path;
        OIDC_CLIENTS_GRAFANA_NAME = "Grafana";
        OIDC_CLIENTS_GRAFANA_TRUSTEDREDIRECTURIS = "https://grafana.angel.pizza/login/generic_oauth";

        LOG_STREAMS_AUDIT_ENABLED = true;
      };
    };

    newt.blueprint.proxy-resources.tinyauth = {
      name = "TinyAuth";
      protocol = "http";
      full-domain = domain;
      auth.sso-enabled = false;
      targets = [
        {
          hostname = "127.0.0.1";
          method = "http";
          inherit port;
          healthcheck = {
            enabled = true;
            hostname = "127.0.0.1";
            method = "GET";
            inherit port;
            path = "/api/healthz";
            scheme = "http";
            status = 200;
          };
        }
      ];
    };
  };
}
