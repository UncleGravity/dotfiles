{
  config,
  pkgs,
  ...
}: let
  domain = "auth.angel.pizza";
  port = 3000;
  statePath = "/var/lib/tinyauth";
  mkOidcGenerator = {
    displayName,
    files ? {},
    render ? "",
  }: {
    prompts.client-secret = {
      description = "${displayName} OIDC client secret";
      type = "hidden";
      persist = true;
    };
    files =
      {
        client-secret = {
          owner = "tinyauth";
          group = "tinyauth";
          mode = "0400";
          restartUnits = ["tinyauth.service"];
        };
      }
      // files;
    script = ''
      if [[ ! -s "$out/client-secret" ]]; then
        echo "${displayName} OIDC client secret must not be empty" >&2
        exit 1
      fi
      originalSize="$(wc -c < "$out/client-secret")"
      singleLineSize="$(tr -d '\r\n' < "$out/client-secret" | wc -c)"
      if [[ "$originalSize" -ne "$singleLineSize" ]]; then
        echo "${displayName} OIDC client secret must be a single line" >&2
        exit 1
      fi

      clientSecret="$(cat "$out/client-secret")"
      ${render}
    '';
  };
in {
  clan.core.vars.generators = {
    tinyauth-users = {
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

    tinyauth-oidc-open-webui = mkOidcGenerator {
      displayName = "Open WebUI";
      files.environment = {
        mode = "0400";
        restartUnits = ["open-webui.service"];
      };
      render = ''
        printf 'OAUTH_CLIENT_SECRET=%s\n' "$clientSecret" > "$out/environment"
      '';
    };

    tinyauth-oidc-dawarich = mkOidcGenerator {
      displayName = "Dawarich";
      files.environment = {
        owner = "dawarich";
        group = "dawarich";
        mode = "0400";
        restartUnits = [
          "dawarich-sidekiq-all.service"
          "dawarich-web.service"
        ];
      };
      render = ''
        printf 'OIDC_CLIENT_SECRET=%s\n' "$clientSecret" > "$out/environment"
      '';
    };

    tinyauth-oidc-grafana = mkOidcGenerator {
      displayName = "Grafana";
      files.grafana-client-secret = {
        owner = "grafana";
        group = "grafana";
        mode = "0400";
        restartUnits = ["grafana.service"];
      };
      render = ''
        cp "$out/client-secret" "$out/grafana-client-secret"
      '';
    };

    tinyauth-oidc-pangolin = mkOidcGenerator {
      displayName = "Pangolin";
    };
  };

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
        OIDC_CLIENTS_OPENWEBUI_CLIENTSECRETFILE = config.clan.core.vars.generators.tinyauth-oidc-open-webui.files.client-secret.path;
        OIDC_CLIENTS_OPENWEBUI_NAME = "Open WebUI";
        OIDC_CLIENTS_OPENWEBUI_TRUSTEDREDIRECTURIS = "https://ai.angel.pizza/oauth/oidc/callback";
        OIDC_CLIENTS_DAWARICH_CLIENTID = "19ca6a2e-1dd9-4b02-b4f4-3b8520cd878e";
        OIDC_CLIENTS_DAWARICH_CLIENTSECRETFILE = config.clan.core.vars.generators.tinyauth-oidc-dawarich.files.client-secret.path;
        OIDC_CLIENTS_DAWARICH_NAME = "Dawarich";
        OIDC_CLIENTS_DAWARICH_TRUSTEDREDIRECTURIS = "https://dawarich.angel.pizza/users/auth/openid_connect/callback";
        OIDC_CLIENTS_PANGOLIN_CLIENTID = "a2ceaf54-0329-422e-81f8-ef801a87ac1d";
        OIDC_CLIENTS_PANGOLIN_CLIENTSECRETFILE = config.clan.core.vars.generators.tinyauth-oidc-pangolin.files.client-secret.path;
        OIDC_CLIENTS_PANGOLIN_NAME = "Pangolin";
        OIDC_CLIENTS_PANGOLIN_TRUSTEDREDIRECTURIS = "https://pangolin.angel.pizza/auth/idp/1/oidc/callback";
        OIDC_CLIENTS_GRAFANA_CLIENTID = "686c07de-8601-48af-8ac1-59c2a05856c0";
        OIDC_CLIENTS_GRAFANA_CLIENTSECRETFILE = config.clan.core.vars.generators.tinyauth-oidc-grafana.files.client-secret.path;
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
