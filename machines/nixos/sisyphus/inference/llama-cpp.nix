{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  home = config.users.users.${username}.home;
  llamaCpp = pkgs.llama-cpp.override {cudaSupport = true;};
  # model = "${home}/models/unsloth/Qwen3.5-27B-MTP-GGUF/Qwen3.5-27B-UD-Q4_K_XL.gguf";
  model = "${home}/models/abliterated/llmfan46/Qwen3.6-27B-uncensored-heretic-v2-Native-MTP-Preserved-Q4_K_M.gguf";
in {
  config = lib.mkIf config.my.nvidiaAi.enable {
    environment.systemPackages = [llamaCpp];

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
        ExecStart = "${llamaCpp}/bin/llama-server -m ${model} -ngl 99 -c 32768 -t 8 --port 8080 --host 0.0.0.0 --spec-type draft-mtp --spec-draft-n-max 3";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
