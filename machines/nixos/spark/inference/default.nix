{
  node,
  username,
  ...
}: {
  imports = [
    ./huggingface.nix
    # ./open-webui.nix
    ./vllm-laguna.nix
  ];

  services.vllm-laguna = {
    enable = node.controller;
    autoStart = false;
    listenAddress = node.managementAddress;

    # Leave headroom for non-model GPU allocations.
    gpuMemoryUtilization = 0.75;
  };

  systemd.tmpfiles.rules = [
    "d /srv/models 0755 ${username} users -"
  ];
}
