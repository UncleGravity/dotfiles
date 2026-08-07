{
  config,
  pkgs,
  ...
}: let
  domain = "ai.angel.pizza";
  apiDomain = "ai-api.angel.pizza";
  authDomain = "auth.angel.pizza";
  litellmPort = 4000;
  openWebuiPort = 8080;
  searxPort = 8888;
  openWebuiClientId = "57d07a26-42eb-46fc-92a8-b94ec7a7ff40";
  python3Packages = pkgs.python3Packages.overrideScope (_final: prev: {
    langfuse = prev.langfuse.overridePythonAttrs (old: {
      pythonRelaxDeps = (old.pythonRelaxDeps or []) ++ ["wrapt"];
    });
  });
in {
  # SECRETS
  sops = {
    secrets = {
      "litellm/master-key".sopsFile = ../../../../secrets/secrets.yaml;
      "searx/secret-key".sopsFile = ../secrets/secrets.yaml;
    };

    templates = {
      "litellm.env" = {
        content = ''
          LITELLM_MASTER_KEY=${config.sops.placeholder."litellm/master-key"}
        '';
        restartUnits = ["litellm.service"];
      };

      "open-webui.env" = {
        content = ''
          OAUTH_CLIENT_SECRET=${config.sops.placeholder."tinyauth/oidc/open-webui-client-secret"}
          OPENAI_API_KEY=${config.sops.placeholder."litellm/master-key"}
        '';
        restartUnits = ["open-webui.service"];
      };

      "searx.env" = {
        content = ''
          SEARXNG_SECRET_KEY=${config.sops.placeholder."searx/secret-key"}
        '';
        restartUnits = [
          "searx-init.service"
          "searx.service"
        ];
      };
    };
  };

  # SERVICES
  services = {
    litellm = {
      enable = true;
      package = pkgs.litellm.override {inherit python3Packages;};
      host = "127.0.0.1";
      port = litellmPort;
      environmentFile = config.sops.templates."litellm.env".path;
      settings = {
        general_settings.master_key = "os.environ/LITELLM_MASTER_KEY";
        model_list = [
          {
            model_name = "sisyphus-current";
            litellm_params = {
              model = "openai/qwen3.6-27b-heretic";
              api_base = "http://192.168.1.139:8080/v1";
              api_key = "unused";
            };
          }
          {
            model_name = "spark-current";
            litellm_params = {
              model = "openai/spark-current";
              api_base = "http://192.168.1.31:8888/v1";
              api_key = "unused";
            };
          }
        ];
      };
    };

    open-webui = {
      enable = true;
      host = "127.0.0.1";
      port = openWebuiPort;
      environmentFile = config.sops.templates."open-webui.env".path;
      environment = {
        WEBUI_URL = "https://${domain}";
        WEBUI_AUTH = "True";
        ENABLE_PERSISTENT_CONFIG = "False";
        BYPASS_MODEL_ACCESS_CONTROL = "True";
        ENABLE_WEB_SEARCH = "True";
        WEB_SEARCH_ENGINE = "searxng";
        SEARXNG_QUERY_URL = "http://127.0.0.1:${toString searxPort}/search?q=<query>";
        ENABLE_OAUTH_SIGNUP = "True";
        OAUTH_AUTO_REDIRECT = "True";
        ENABLE_LOGIN_FORM = "False";
        OAUTH_PROVIDER_NAME = "TinyAuth";
        OAUTH_CLIENT_ID = openWebuiClientId;
        OPENID_PROVIDER_URL = "https://${authDomain}/.well-known/openid-configuration";
        OPENID_REDIRECT_URI = "https://${domain}/oauth/oidc/callback";
        OAUTH_SCOPES = "openid email profile";
        ENABLE_OAUTH_ROLE_MANAGEMENT = "True";
        OAUTH_ROLES_CLAIM = "preferred_username";
        OAUTH_ALLOWED_ROLES = "angel,jay";
        OAUTH_ADMIN_ROLES = "angel";
        ENABLE_OAUTH_ID_TOKEN_COOKIE = "False";
        ENABLE_OLLAMA_API = "False";
        ENABLE_OPENAI_API = "True";
        OPENAI_API_BASE_URL = "http://127.0.0.1:${toString litellmPort}/v1";
        DEFAULT_MODELS = "sisyphus-current";
        ENABLE_VERSION_UPDATE_CHECK = "False";
        ENABLE_OPENAI_API_PASSTHROUGH = "False";
        ENABLE_PIP_INSTALL_FRONTMATTER_REQUIREMENTS = "False";
      };
    };

    searx = {
      enable = true;
      environmentFile = config.sops.templates."searx.env".path;
      settings = {
        server = {
          bind_address = "127.0.0.1";
          port = searxPort;
          base_url = "http://127.0.0.1:${toString searxPort}/";
          secret_key = "$SEARXNG_SECRET_KEY";
        };
        search.formats = [
          "html"
          "json"
        ];
      };
    };

    newt.blueprint.proxy-resources.ai = {
      name = "AI";
      protocol = "http";
      full-domain = domain;
      auth.sso-enabled = false;
      targets = [
        {
          hostname = "127.0.0.1";
          method = "http";
          port = openWebuiPort;
        }
      ];
    };

    newt.blueprint.proxy-resources.ai-api = {
      name = "AI API";
      protocol = "http";
      full-domain = apiDomain;
      auth.sso-enabled = false;
      targets = [
        {
          hostname = "127.0.0.1";
          method = "http";
          port = litellmPort;
        }
      ];
    };
  };

  systemd.services.open-webui = {
    after = [
      "litellm.service"
      "searx.service"
    ];
    wants = [
      "litellm.service"
      "searx.service"
    ];
  };
}
