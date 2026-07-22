{
  node,
  pkgs,
  ...
}: let
  openWebuiPython = pkgs.python3Packages.overrideScope (
    _final: prev: {
      torchaudio = prev.torchaudio.overridePythonAttrs (old: {
        disabledTests =
          (old.disabledTests or [])
          ++ [
            # AArch64 FFT batching can exceed the upstream float tolerance.
            "test_batch_melspectrogram"
          ];
      });
    }
  );
in {
  services.open-webui = {
    enable = node.controller;
    package = pkgs.open-webui.override {python3Packages = openWebuiPython;};
    host = "127.0.0.1";
    port = 8080;
    environment = {
      ENABLE_OLLAMA_API = "False";
      ENABLE_OPENAI_API = "True";
      OPENAI_API_BASE_URL = "http://${node.managementAddress}:8000/v1";
      OPENAI_API_KEY = "unused";
      DEFAULT_MODELS = "poolside/Laguna-S-2.1-NVFP4";
      ENABLE_VERSION_UPDATE_CHECK = "False";
      ENABLE_OPENAI_API_PASSTHROUGH = "False";
      ENABLE_PIP_INSTALL_FRONTMATTER_REQUIREMENTS = "False";
    };
  };
}
