let
  modelFile = "Qwen3.6-27B-uncensored-heretic-v2-Native-MTP-Preserved-Q4_K_M.gguf";
  modelPath = "/models/primary/${modelFile}";
  port = 8080;
in {
  my.inference.recipes.qwen3-6-heretic-27b = {
    models.primary = {
      repo = "llmfan46/Qwen3.6-27B-uncensored-heretic-v2-Native-MTP-Preserved-GGUF";
      revision = "a6b6a6d9385fe7850644e56bfdc93a04a6cb2ee8";
      selection.include = [modelFile];
    };

    image.context = ./.;

    container = {
      devices = ["nvidia.com/gpu=all"];
      args = [
        "--model"
        modelPath
        "--alias"
        "qwen3.6-27b-heretic"
        "--n-gpu-layers"
        "99"
        "--ctx-size"
        "32768"
        "--threads"
        "8"
        "--port"
        (toString port)
        "--host"
        "0.0.0.0"
        "--spec-type"
        "draft-mtp"
        "--spec-draft-n-max"
        "3"
      ];
    };

    endpoint = {
      inherit port;
      startupTimeoutSeconds = 300;
    };
  };

  networking.firewall.allowedTCPPorts = [port];
}
