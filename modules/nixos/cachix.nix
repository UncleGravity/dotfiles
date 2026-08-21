
{config, ...}: let
  authToken = config.clan.core.vars.generators.cachix.files.auth-token;
  deployCredentials = config.clan.core.vars.generators.cachix-deploy.files.credentials;
in {
  clan.core.vars.generators.cachix-deploy = {
    share = true;

    prompts.agent-token = {
      description = "Cachix Deploy agent token";
      type = "hidden";
      persist = true;
    };

    files.credentials = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = ["cachix-agent.service"];
    };

    script = ''
      token="$(cat "$prompts/agent-token")"
      token="''${token#CACHIX_AGENT_TOKEN=}"
      if [[ -z "$token" || "$token" == *$'\n'* ]]; then
        echo "Cachix Deploy agent token must be a non-empty single line" >&2
        exit 1
      fi

      printf 'CACHIX_AGENT_TOKEN=%s\n' "$token" > "$out/credentials"
    '';
  };

  clan.core.vars.generators.cachix.files.auth-token.restartUnits = [
    "cachix-watch-store-agent.service"
  ];

  # Pull Github CI deployments
  services.cachix-agent = {
    enable = true;
    credentialsFile = deployCredentials.path;
  };

  # Upload locally built Nix store paths to Cachix.
  services.cachix-watch-store = {
    enable = true;
    cacheName = "unclegravity-nix";
    cachixTokenFile = authToken.path;
  };
}
