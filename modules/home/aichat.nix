{...}: {

  home.shellAliases."ai"="aichat";

  programs.aichat = {
    enable = true;
    settings = {
      model = "claude";
      stream = true;
      save = true;
      keybindings = "emacs";
      editor = null;
      wrap = "no";
      wrap_code = false;
      clients = [
        {type = "openai";}
        {type = "claude";}
        {
          type = "openai-compatible";
          name = "ollama";
          api_base = "http://localhost:11434/v1";
          models = [
            {name = "gemma2:27b";}
            {name = "deepseek-coder-v2";}
            {name = "hf.co/bartowski/Qwen2.5-Coder-32B-Instruct-GGUF:Q6_K_L";}
          ];
        }
      ];
    };
  };
}
