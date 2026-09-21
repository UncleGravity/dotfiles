{
  programs.pi-coding-agent = {
    settings = {
      defaultProvider = "litellm";
      defaultModel = "spark-current";
      defaultThinkingLevel = "low";

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
            contextWindow = 131072;
            maxTokens = 8192;
          }
          {
            id = "spark-current";
            name = "Spark Current";
            reasoning = true;
            input = ["text" "image"];
            contextWindow = 1048576;
            maxTokens = 16384;
            thinkingLevelMap = {
              off = null;
              minimal = null;
              low = "low";
              medium = null;
              high = "high";
              xhigh = null;
              max = "max";
            };
            compat = {
              supportsDeveloperRole = false;
              supportsReasoningEffort = false;
              thinkingFormat = "chat-template";
              chatTemplateKwargs.reasoning_effort."$var" = "thinking.effort";
            };
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
