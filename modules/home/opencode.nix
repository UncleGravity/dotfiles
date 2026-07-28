{lib, ...}: {
  programs.opencode = {
    enable = true;

    settings = {
      model = lib.mkDefault "llamacpp/models/Bonsai-4B/Bonsai-4B-Q1_0.gguf";
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

        penzai = {
          npm = "@ai-sdk/openai-compatible";
          name = "llama.cpp (local)";

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
