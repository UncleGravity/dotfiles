{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  home = config.users.users.${username}.home;
  llamaCpp = pkgs.llama-cpp.override {cudaSupport = true;};
  apiKey = config.sops.secrets."sisyphus/llama-api-key";
  # model = "${home}/models/unsloth/Qwen3.5-27B-MTP-GGUF/Qwen3.5-27B-UD-Q4_K_XL.gguf";
  model = "${home}/models/abliterated/llmfan46/Qwen3.6-27B-uncensored-heretic-v2-Native-MTP-Preserved-Q4_K_M.gguf";
in {
  config = lib.mkIf config.my.nvidiaAi.enable {
    environment.systemPackages = [llamaCpp];

    sops.secrets."sisyphus/llama-api-key" = {
      owner = username;
      mode = "0400";
      restartUnits = ["llama-server.service"];
    };

    systemd.services.llama-server = {
      description = "llama.cpp server";
      wantedBy = ["multi-user.target"];
      after = ["nvidia-persistenced.service"];
      wants = ["nvidia-persistenced.service"];
      unitConfig.RequiresMountsFor = [model];

      environment.HOME = home;
      serviceConfig = {
        User = username;
        Group = "users";
        ExecStart = "${llamaCpp}/bin/llama-server -m ${model} --alias qwen3.6-27b-heretic -ngl 99 -c 32768 -t 8 --port 8080 --host 127.0.0.1 --api-key-file ${apiKey.path} --spec-type draft-mtp --spec-draft-n-max 3";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    services.newt.blueprint.proxy-resources.ai = {
      name = "ai";
      protocol = "http";
      full-domain = "ai.angel.pizza";
      targets = [
        {
          hostname = "localhost";
          method = "http";
          port = 8080;
          healthcheck = {
            enabled = true;
            hostname = "localhost";
            method = "GET";
            port = 8080;
            path = "/health";
            scheme = "http";
            status = 200;
          };
        }
      ];
    };
  };
}
