{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  # Toggle
  cfg = config.my.tmux;

  tmuxConf = ./tmux.conf;
in {
  options.my.tmux.enable = lib.mkEnableOption "Enable Home-Manager tmux setup";

  config = lib.mkIf cfg.enable {
    programs.fzf.tmux.enableShellIntegration = true;

    # SESH
    programs.sesh = {
      enable = true;
      enableAlias = true;
      enableTmuxIntegration = false; # <prefix>+s
      # tmuxKey = "k";
      settings = {
        session = [
          {
            name = "dotfiles";
            path = "~/nix/";
            startup_command = "nvim";
          }
        ];
      };
    };

    programs.tmux = {
      enable = true;
      shell = "${pkgs.zsh}/bin/zsh";
      sensibleOnTop = true;
      plugins = [
        pkgs.tmuxPlugins.vim-tmux-navigator
        {
          plugin = inputs.tmux-powerkit.packages.${pkgs.stdenv.hostPlatform.system}.default;
          extraConfig = ''
            set -g @powerkit_theme "tokyo-night"
            set -g @powerkit_theme_variant "night"
            set -g @powerkit_session_icon "\uebc8"
            set -g @powerkit_plugins ""
            # set -g @powerkit_separator_style "rounded"
            # set -g @powerkit_edge_separator_style "none"
            set -g @powerkit_elements_spacing "both"
            set -g @powerkit_transparent "true"
          '';
        }
      ];

      extraConfig =
        builtins.readFile tmuxConf
        + ''
          # Ensure tmux uses zsh for new panes/windows
          set-option -g default-command "${pkgs.zsh}/bin/zsh -l"
        '';
    };
  };
}
