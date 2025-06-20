{ config, lib, pkgs, ... }:

let
  # Toggle
  cfg = config.my.tmux;

  # Path to the original, hand-written tmux.conf that lives in the dotfiles
  # repository.  We don't modify it – we only read it at build time.
  tmuxConf = ./tmux.conf;

  # Plugins built via Nix (no TPM needed)
  # sensiblePlugin = pkgs.tmuxPlugins.sensible;
  vim-tmux-navigator = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "vim-tmux-navigator";
    rtpFilePath = "vim-tmux-navigator.tmux";
    version = "unstable-2025-06-09";
    src = pkgs.fetchFromGitHub {
      owner = "christoomey";
      repo = "vim-tmux-navigator";
      rev = "412c474e97468e7934b9c217064025ea7a69e05e";
      hash = "sha256-8A+Yt9uhhAP76EiqUopE8vl7/UXkgU2x000EOcF7pl0=";
    };
  };
  tokyoNightPlugin = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-tokyo-night";
    rtpFile    = "tmux-tokyo-night.tmux";
    version    = "unstable-2025-05-27";
    src = pkgs.fetchFromGitHub {
      owner = "fabioluciano";
      repo  = "tmux-tokyo-night";
      rev   = "54870913b2efd343da78352acd47df975331e37e";
      sha256 = "sha256-OSWjOPT+XxAvGhquxoFlmimJbqSIlHmIOLClYZM/L9k=";
    };
  };

in {
  # Option the user can flip
  options.my.tmux.enable = lib.mkEnableOption "Enable Home-Manager tmux setup";

  # Actual configuration
  config = lib.mkIf cfg.enable {

    programs.fzf.tmux.enableShellIntegration = true;
    programs.sesh = {
      enable = true;
      enableAlias = true;
      settings = {
        session = [
          {
            name = "dotfiles";
            path = "~/nix/";
            startup_command = "nvim";
          }
          {
            name = "neovim config";
            path = "~/.config/nvim/";
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