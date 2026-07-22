{...}: {
  # Shared home config for all Spark nodes; per-node overrides are not
  # expected — keep the cluster homogeneous.

  programs.opencode = {
    enable = true;

    settings = {
      autoupdate = false;
      model = "spark/poolside/Laguna-S-2.1-NVFP4";
      small_model = "spark/poolside/Laguna-S-2.1-NVFP4";

      provider.spark = {
        npm = "@ai-sdk/openai-compatible";
        name = "DGX Spark";

        options = {
          baseURL = "http://192.168.1.31:8000/v1";
          apiKey = "dummy";
          timeout = 900000;
          chunkTimeout = 300000;
        };

        models."poolside/Laguna-S-2.1-NVFP4" = {
          name = "Laguna S 2.1 NVFP4";
          limit = {
            context = 262144;
            output = 32768;
          };
        };
      };
    };
  };
}
