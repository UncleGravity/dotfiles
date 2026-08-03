{
  imports = [./recipes];

  my.inference = {
    enable = true;
    operators = ["angel"];
    instances.qwen = {
      recipe = "qwen3-6-heretic-27b";
      autoStart = true;
    };
  };
}
