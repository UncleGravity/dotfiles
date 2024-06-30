{config, pkgs, inputs, ...}:

# Testing importing NixOS modules from home-manager

{
  # VSCode Server (NixOS)
  imports = [
    inputs.vscode-server.homeModules.default
  ];

  services.vscode-server.enable = true;
}