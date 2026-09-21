{lib, ...}: {
  programs.codex = {
    enable = true;

    # Select with `codex --profile spark`.
    profiles.spark = {
      model = "spark-current";
      model_provider = "litellm";
      model_context_window = 1048576;
      model_reasoning_effort = lib.mkDefault "low";
      web_search = "disabled";

      model_providers.litellm = {
        name = "LiteLLM";
        base_url = "https://ai-api.angel.pizza/v1";
        env_key = "LITELLM_API_KEY";
        wire_api = "responses";
      };
    };
  };
}
