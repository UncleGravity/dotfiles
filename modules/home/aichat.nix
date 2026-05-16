{...}: {
  programs.aichat = {
    enable = true;
    settings = {
      clients = [
        {type = "openai";}
        {type = "claude";}
        {type = "gemini";}
      ];
      model = "openai";
      editor = null;
      keybindings = "emacs";
      save = true;
      stream = true;
      wrap = "no";
      wrap_code = false;
    };
  };

  home.shellAliases."ai" = "aichat";
}
