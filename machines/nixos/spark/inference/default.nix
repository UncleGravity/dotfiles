{
  lib,
  node,
  sparkNodes,
  username,
  ...
}: let
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
    ./huggingface.nix
    ./recipes
    # ./open-webui.nix
  ];

  my.inference = {
    enable = true;
    operators = [username];
    protectHostMemory = true;
    controlNode = "spark-01";
    nodes = inferenceNodes;

    instances.laguna = {
      recipe = "laguna-vllm";
      nodes = ["spark-01"];
      autoStart = false;
    };

    instances.cluster-smoke = {
      recipe = "cluster-smoke";
      nodes = ["spark-01" "spark-02"];
      autoStart = false;
    };

    instances.deepseek-v4-flash-0731 = {
      recipe = "deepseek-v4-flash-0731";
      nodes = ["spark-01" "spark-02"];
      autoStart = false;
    };
  };

  networking.firewall.allowedTCPPorts = lib.optionals node.controller [8000 8888];
}
