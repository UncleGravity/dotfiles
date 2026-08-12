{
  programs.pi-coding-agent = {
    settings = {
      defaultProvider = "litellm";
      defaultModel = "spark-current";

      # Cycle through these with Ctrl+P
      enabledModels = [
        "litellm/spark-current"
        "litellm/sisyphus-current"
      ];
    };

    models.providers = {
      litellm = {
        baseUrl = "https://ai-api.angel.pizza/v1";
        api = "openai-completions";
        apiKey = "$LITELLM_API_KEY";
        models = [
          {
            id = "sisyphus-current";
            name = "Sisyphus Current";
            contextWindow = 32768;
            maxTokens = 8192;
          }
          {
            id = "spark-current";
            name = "Spark Current";
            contextWindow = 131072;
            maxTokens = 16384;
          }
        ];
      };

      penzai = {
        baseUrl = "http://127.0.0.1:8080/v1";
        api = "openai-completions";
        apiKey = "llama-server";
        compat = {
          supportsDeveloperRole = false;
          supportsReasoningEffort = false;
        };
        models = [
          {
            id = "models/Bonsai-4B/Bonsai-4B-Q1_0.gguf";
            name = "Bonsai 4B Q1_0";
            contextWindow = 5120;
            maxTokens = 1024;
          }
        ];
      };
    };
  };
}
