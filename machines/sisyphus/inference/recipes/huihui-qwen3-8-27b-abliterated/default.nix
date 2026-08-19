let
  modelFile = "Huihui-Qwen3.8-27B-abliterated-Q4_K.gguf";
  mmprojFile = "mmproj-model-bf16.gguf";
  modelRoot = "/models/primary";
  port = 8080;
in {
  my.inference.recipes.huihui-qwen3-8-27b-abliterated = {
    models.primary = {
      repo = "huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF";
      revision = "2379b9294c14c0e55bd2ea5ac84d8bb9ffdfd98b";
      selection.include = [
        modelFile
        mmprojFile
      ];
    };

    image.context = ./.;

    container = {
      devices = ["nvidia.com/gpu=all"];
      args = [
        "--model"
        "${modelRoot}/${modelFile}"
        "--mmproj"
        "${modelRoot}/${mmprojFile}"
        "--alias"
        "huihui-qwen3.8-27b"
        "--host"
        "0.0.0.0"
        "--port"
        (toString port)
        "--ctx-size"
        "131072"
        "--spec-type"
        "draft-mtp"
        "--spec-draft-n-max"
        "2"
        "--cache-type-k"
        "q8_0"
        "--cache-type-v"
        "q8_0"
        "--parallel"
        "1"
        "--jinja"
        "--temp"
        "1.0"
        "--top-p"
        "0.95"
        "--top-k"
        "20"
        "--min-p"
        "0.0"
        "--reasoning-preserve"
        "--agent"
      ];
    };

    endpoint = {
      inherit port;
      startupTimeoutSeconds = 300;
    };
  };

  networking.firewall.allowedTCPPorts = [port];
}
