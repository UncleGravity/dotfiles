{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cluster = config.my.sparkCluster;
  home = config.users.users.${username}.home;
  hubEnvironment = {
    HF_HUB_ENABLE_HF_TRANSFER = "1";
    HF_HUB_DISABLE_TELEMETRY = "1";
    HF_HUB_DISABLE_XET = "1";
  };
  tokenPath = config.clan.core.vars.generators."spark-huggingface-spark".files.token.path;
in {
  # Downloads happen on the controller; workers receive replicas over the
  # fabric as described in docs/machines/spark/models.md.

  environment.systemPackages = [
    # `hf` CLI plus python3 with huggingface_hub for scripting.
    (pkgs.python3.withPackages (ps:
      with ps; [
        huggingface-hub
        hf-transfer
      ]))
  ];

  environment.variables =
    hubEnvironment
    // lib.optionalAttrs cluster.isController {
      HF_TOKEN_PATH = tokenPath;
    };

  my.inference.serviceEnvironment =
    hubEnvironment
    // lib.optionalAttrs cluster.isController {
      HF_TOKEN_PATH = tokenPath;
    };

  systemd.tmpfiles.rules = lib.optional cluster.isController "r ${home}/.cache/huggingface/token - - - - -";
}
