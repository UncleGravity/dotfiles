{lib, ...}: {
  programs.opencode = {
    enable = true;

    settings = {
      model = lib.mkDefault "litellm/spark-current";
      # model = lib.mkDefault "opencode/glm-5.2";

      # -----------------------------------------------
      # Custom agents
      agent.mini = {
        description = "Low-context local coding agent";
        mode = "primary";
        # model = "llamacpp/models/Bonsai-4B/Bonsai-4B-Q1_0.gguf";

        permission = {
          "*" = "deny";
          bash = "allow";
          read = "allow";
          edit = "allow";
        };
      };

      # -----------------------------------------------
      # LLM Providers
      provider = {
        lmstudio = {
          npm = "@ai-sdk/openai-compatible";
          name = "LM Studio (local)";

          options = {
            baseURL = "http://127.0.0.1:1234/v1";
            apiKey = "lm-studio";
          };
        };

        litellm = {
          npm = "@ai-sdk/openai-compatible";
          name = "LiteLLM";

          options = {
            baseURL = "https://ai-api.angel.pizza/v1";
            apiKey = "{env:LITELLM_API_KEY}";
          };

          models = {
            "sisyphus-current" = {
              name = "Sisyphus Current";
              limit = {
                context = 131072;
                output = 8192;
              };
            };

            "spark-current" = {
              name = "Spark Current";
              attachment = true;
              reasoning = true;
              tool_call = true;
              interleaved.field = "reasoning_content";
              limit = {
                context = 1048576;
                output = 16384;
              };
              modalities = {
                input = ["text" "image"];
                output = ["text"];
              };
              options.chat_template_kwargs.reasoning_effort = "low";
              variants = {
                low.chat_template_kwargs.reasoning_effort = "low";
                medium.disabled = true;
                high.chat_template_kwargs.reasoning_effort = "high";
                max.chat_template_kwargs.reasoning_effort = "max";
              };
            };
          };
        };

        penzai = {
          npm = "@ai-sdk/openai-compatible";
          name = "penzai FPGA (local)";

          options = {
            baseURL = "http://127.0.0.1:8080/v1";
            apiKey = "llama-server";
          };

          models."models/Bonsai-4B/Bonsai-4B-Q1_0.gguf" = {
            name = "Bonsai 4B Q1_0";
            limit = {
              context = 5120;
              output = 1024;
            };
          };
        };
      };
      # -----------------------------------------------
    };
  };

  home.shellAliases."oc" = "opencode";
}
