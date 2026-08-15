let
  modelFile = "Qwen3.8-27B-UD-Q4_K_XL.gguf";
  mmprojFile = "mmproj-BF16.gguf";
  modelRoot = "/models/primary";
  port = 8080;
in {
  my.inference.recipes.qwen3-8-27b = {
    models.primary = {
      repo = "unsloth/Qwen3.8-27B-GGUF";
      revision = "fe1e2a23d973adb629709749dc4f6756df66ef10";
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
        "qwen3.8-27b"
        "--host"
        "0.0.0.0"
        "--port"
        (toString port)
        "--ctx-size"
        "65536"
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
