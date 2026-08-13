{
  config,
  lib,
  node,
  sparkNodes,
  username,
  ...
}: let
  coordinationPublicKey = builtins.replaceStrings ["\n" "\r"] ["" ""] (
    builtins.readFile ../../../../../vars/per-machine/spark-01/spark-coordination-spark/id_ed25519.pub/value
  );
  inferenceNodes =
    lib.mapAttrs (_: peer: {
      platform = "linux/arm64";
      inherit (peer) managementAddress;
      sshHostKey = peer.sshHostKey or null;
      fabric = {
        fabric0 = "10.100.0.${toString peer.id}";
        fabric1 = "10.100.1.${toString peer.id}";
      };
    })
    sparkNodes;
in {
  imports = [
    ./coordination.nix
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
    controlNode = "spark-01";
    nodes = inferenceNodes;
    coordination =
      {
        authorizedKeys = [
          coordinationPublicKey
          # TODO: Remove after every Spark node passes the dedicated-key rollout.
          sparkNodes.spark-01.sshHostKey
        ];
      }
      // lib.optionalAttrs node.controller {
        identityFile = config.clan.core.vars.generators.spark-coordination-spark.files.id_ed25519.path;
      };

    instances.laguna = {
      recipe = "laguna-vllm";
      nodes = ["spark-01"];
      autoStart = false;
    };

    instances.deepseek-v4-flash-0731 = {
      recipe = "deepseek-v4-flash-0731";
      nodes = ["spark-01" "spark-02"];
      autoStart = false;
    };

    instances.glm52 = {
      recipe = "glm52-b12x-spark";
      nodes = ["spark-01" "spark-02" "spark-03" "spark-04"];
      autoStart = false;
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

  networking.firewall.allowedTCPPorts = lib.optionals node.controller [8000 8888];
}
