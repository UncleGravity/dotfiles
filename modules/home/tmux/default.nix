{ config, lib, pkgs, inputs, ... }:

let
  # Toggle
  cfg = config.my.tmux;

  tmuxConf = ./tmux.conf;

  # Plugins built via Nix (no TPM needed)
  # Using flake inputs instead of manual fetchFromGitHub
  vim-tmux-navigator = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "vim-tmux-navigator";
    rtpFilePath = "vim-tmux-navigator.tmux";
    version = "unstable";
    src = inputs.tmux-vim-navigator;
  };
  tokyoNightPlugin = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-tokyo-night";
    rtpFile = "tmux-tokyo-night.tmux";
    version = "unstable";
    src = inputs.tmux-tokyo-night;
  };

in {
  options.my.tmux.enable = lib.mkEnableOption "Enable Home-Manager tmux setup";

  config = lib.mkIf cfg.enable {

    programs.fzf.tmux.enableShellIntegration = true;
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

      extraConfig = builtins.readFile tmuxConf + ''
        # Ensure tmux uses zsh for new panes/windows
        # set-option -g default-shell "${pkgs.zsh}/bin/zsh"
        set-option -g default-command "${pkgs.zsh}/bin/zsh -l"
        # -----------------------------------------
        # THEME
        # -----------------------------------------
        # set -g @theme_session_icon "\uf11c " # 
        set -g @theme_session_icon "\uebc8" # 
        set -g @theme_variation 'night'
        # set -g @theme_plugins 'datetime'
        set -g @theme_disable_plugins 1
        set -g @theme_transparent_status_bar 'true'
        set -g @theme_active_pane_border_style '#83a598'

        run-shell ${vim-tmux-navigator}/share/tmux-plugins/vim-tmux-navigator/vim-tmux-navigator.tmux
        run-shell ${tokyoNightPlugin}/share/tmux-plugins/tmux-tokyo-night/tmux-tokyo-night.tmux
      '';
    };
  };
}
