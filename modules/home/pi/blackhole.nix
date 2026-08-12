{pkgs, ...}: let
  blackholeConfig = (pkgs.formats.json {}).generate "pi-blackhole-config.json" {
    compaction = "auto";
    compactionEngine = "blackhole";
    tailBehavior = "pi-default";
    compactAfterTokens = 81000;
    memory = true;
    sessionFallback = false;

    model = {
      provider = "litellm";
      id = "spark-current";
      thinking = "low";
      contextWindow = 131072;
    };
  };
in {
  programs.pi-coding-agent.settings = {
    compaction = {
      enabled = true;
      reserveTokens = 8192;
      keepRecentTokens = 8000;
    };

    packages = ["npm:pi-blackhole"];
  };

  home.file.".pi/agent/pi-blackhole/pi-blackhole-config.json".source = blackholeConfig;
}
