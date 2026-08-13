{
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    config = {
      virtualisation = {
        darwin-builder = {
          diskSize = 40 * 1024;
          memorySize = 16 * 1024;
        };
        cores = 4;
      };
    };
  };
}
