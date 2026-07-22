{
  config,
  lib,
  node,
  pkgs,
  username,
  ...
}: let
  home = config.users.users.${username}.home;
in {
  # Hugging Face tooling for model staging (see staging.md): downloads happen
  # on the controller, workers receive replicas over the fabric.

  environment.systemPackages = [
    # `hf` CLI plus python3 with huggingface_hub for scripting.
    (pkgs.python3.withPackages (ps:
      with ps; [
        huggingface-hub
        hf-transfer
      ]))
  ];

  environment.variables = {
    HF_HUB_ENABLE_HF_TRANSFER = "1"; # parallel chunked downloads
    HF_HUB_DISABLE_TELEMETRY = "1";
  };

  # The hf CLI and huggingface_hub read ~/.cache/huggingface/token natively.
  # `hf auth login` cannot overwrite it; rotate with:
  #   sops machines/nixos/spark/secrets/controller.yaml
  # Workers are not recipients of controller.yaml.
  sops.secrets = lib.mkIf node.controller {
    "hf/token" = {
      sopsFile = ./secrets/controller.yaml;
      owner = username;
      mode = "0400";
      path = "${home}/.cache/huggingface/token";
    };
  };

  # sops-nix creates missing parent directories as root
  # pre-create them user-owned
  systemd.tmpfiles.rules = [
    "d ${home}/.cache 0700 ${username} users -"
    "d ${home}/.cache/huggingface 0700 ${username} users -"
  ];
}
