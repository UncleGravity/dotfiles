{pkgs, ...}: let
  blackholeConfig = (pkgs.formats.json {}).generate "pi-blackhole-config.json" {
    compaction = "auto";
    compactionEngine = "blackhole";
    tailBehavior = "pi-default";
    # Keep 37.5% of the context free for tool loops, memory, and output.
    compactAfterTokens = 655360;
    memory = true;
    sessionFallback = false;

    model = {
      provider = "litellm";
      id = "spark-current";
      thinking = "low";
      contextWindow = 1048576;
    };
  };
in {
  programs.pi-coding-agent.settings = {
    compaction = {
      enabled = true;
      reserveTokens = 16384;
      keepRecentTokens = 8000;
    };

    packages = ["npm:pi-blackhole"];
  };

  home.file.".pi/agent/pi-blackhole/pi-blackhole-config.json".source = blackholeConfig;
}
