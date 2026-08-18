{
  config,
  lib,
  username,
  ...
}: let
  cluster = config.my.sparkCluster;
in {
  imports = [
    ./huggingface.nix
    ./recipes
    # ./open-webui.nix
  ];

  my.inference = {
    enable = true;
    operators = [username];
    protectHostMemory = true;
    allowSwap = true;
    memoryMaxPercent = 95;
    inherit (cluster) controlNode;
    nodes = cluster.inferenceNodes;
    coordination =
      {
        authorizedKeys = [cluster.coordinationPublicKey];
      }
      // lib.optionalAttrs cluster.isController {
        identityFile = config.clan.core.vars.generators."spark-coordination-spark".files.id_ed25519.path;
      };

    instances = {
      laguna = {
        recipe = "laguna-vllm";
        nodes = ["spark-01"];
        autoStart = false;
      };

      deepseek-v4-flash-0731 = {
        recipe = "deepseek-v4-flash-0731";
        nodes = ["spark-01" "spark-02"];
        autoStart = false;
      };

      glm52 = {
        recipe = "glm52-b12x-spark";
        nodes = ["spark-01" "spark-02" "spark-03" "spark-04"];
        autoStart = false;
      };
    };
  };

  services = {
    # GB10 CUDA allocations are not fully represented by cgroup memory
    # accounting. Protect the host using available memory instead.
    earlyoom = {
      enable = true;
      # GLM 5.2 leaves about 2% free at steady state.
      freeMemThreshold = 2;
      freeMemKillThreshold = 1;
    };
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 32 * 1024;
    }
  ];

  boot.kernel.sysctl."vm.swappiness" = 1;

  networking.firewall.allowedTCPPorts = lib.optionals cluster.isController [8000 8888];
}
