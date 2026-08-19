{
  imports = [./recipes];

  my.inference = {
    enable = true;
    operators = ["angel"];
    instances.qwen = {
      # recipe = "qwen3-6-heretic-27b";
      # recipe = "qwen3-8-27b";
      recipe = "huihui-qwen3-8-27b-abliterated";
      autoStart = true;
    };
  };
}
