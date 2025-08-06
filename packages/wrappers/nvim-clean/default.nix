{ pkgs, ... }: {
  wrappers.nvim-clean = {
    basePackage = pkgs.neovim;
    prependFlags = [
      "-u" "${./config/init.lua}"
      "--cmd" "set runtimepath^=${./config}"
    ];
    pathAdd = [ pkgs.ripgrep pkgs.fd pkgs.git ];
  };
}