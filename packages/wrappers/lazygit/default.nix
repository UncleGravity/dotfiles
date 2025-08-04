{pkgs, ...}: {
  wrappers.lazygit = {
    basePackage = pkgs.lazygit;
    appendFlags = ["-ucf" ./config.yml];
    pathAdd = [
      pkgs.delta
    ];
  };
}
