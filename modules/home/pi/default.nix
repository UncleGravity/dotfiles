{
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./blackhole.nix
    # ./hud.nix
    ./open-tui.nix
    ./permission-system.nix
    ./providers.nix
    ./subagents.nix
  ];

  programs.pi-coding-agent = {
    enable = true;
    package = inputs.multiverse.multiverse.${pkgs.stdenv.hostPlatform.system}.latest.pi-coding-agent;
    extraPackages = [pkgs.nodejs];

    settings = {
      treeFilterMode = "no-tools";
      collapseChangelog = true;
      enableInstallTelemetry = false;

      sessionDir = "${config.xdg.stateHome}/pi/sessions";
      retry.provider.timeoutMs = 900000;

      npmCommand = ["${pkgs.nodejs}/bin/npm"];
    };
  };

  home.sessionVariables.PI_SKIP_VERSION_CHECK = "1";
}
