let
  modelFile = "Qwen3.6-27B-uncensored-heretic-v2-Native-MTP-Preserved-Q4_K_M.gguf";
  modelPath = "/models/primary/${modelFile}";
  apiKeyPath = "/run/secrets/sisyphus/llama-api-key";
in {
  sops.secrets."sisyphus/llama-api-key" = {
    mode = "0400";
  };

  my.inference.recipes.qwen3-6-heretic-27b = {
    models.primary = {
      repo = "llmfan46/Qwen3.6-27B-uncensored-heretic-v2-Native-MTP-Preserved-GGUF";
      revision = "a6b6a6d9385fe7850644e56bfdc93a04a6cb2ee8";
      selection.include = [modelFile];
    };

    image.context = ./.;

    container = {
      devices = ["nvidia.com/gpu=all"];
      mounts = [
        {
          sourcePath = apiKeyPath;
          targetPath = apiKeyPath;
        }
      ];
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
        "8080"
        "--host"
        "127.0.0.1"
        "--api-key-file"
        apiKeyPath
        "--spec-type"
        "draft-mtp"
        "--spec-draft-n-max"
        "3"
      ];
    };

    endpoint = {
      port = 8080;
      startupTimeoutSeconds = 300;
    };
  };
}
