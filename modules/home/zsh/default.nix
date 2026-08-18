{
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ./aliases.nix
    ./fzf.nix
    ./misc.nix
  ];

  programs.zsh = {
    enable = true;
    dotDir = config.xdg.configHome + "/zsh";

    # History -------------------------------------------------------------------------------------
    history = {
      path = "${config.xdg.dataHome}/zsh/zsh_history";
      size = 100000; # 100_000
      save = 100000; # 100_000
      extended = true; # save timestamp
      ignoreAllDups = true; # Keep only latest version of duplicate commands
    };

    autosuggestion.enable = true;
    defaultKeymap = "emacs";
    fastSyntaxHighlighting.enable = true;
    historySubstringSearch = {
      enable = true;
      searchUpKey = ["^[OA" "^[[A"];
      searchDownKey = ["^[OB" "^[[B"];
    };

    # Secrets -------------------------------------------------------------------------------------
    # Loaded on every zsh invocation, keep envExtra LIGHTWEIGHT
    envExtra = ''
      [ -r /run/secrets/vars/shell-env-home/home.sh ] && source /run/secrets/vars/shell-env-home/home.sh
      [ -r /run/secrets/vars/shell-env-work/work.sh ] && source /run/secrets/vars/shell-env-work/work.sh
    '';

    initContent = let
      # -------------------------------------------------------------------------------------------
      p10kInstantPrompt = lib.mkOrder 500 ''
        # Powerlevel10k instant prompt
          if [[ -r "${config.xdg.cacheHome}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
            source "${config.xdg.cacheHome}/p10k-instant-prompt-''${(%):-%n}.zsh"
          fi
      '';
      # -------------------------------------------------------------------------------------------
      zshKeybindings = lib.mkOrder 500 ''
        # Word delimiters
        # This section configures how Zsh treats word boundaries, which affects navigation and text manipulation
        autoload -U select-word-style; select-word-style bash  # Use Bash-style word definitions
        zstyle ':zle:*' word-chars " _-./;@#"  # Define additional characters to be treated as part of words
        zstyle ':zle:*' word-style unspecified

        # Option/Alt key navigation
        # These keybindings enhance text navigation using Option/Alt key combinations
        bindkey "^[[1;3D" backward-word         # Alt+Left: Move cursor to previous word
        bindkey "^[[1;3C" forward-word          # Alt+Right: Move cursor to next word
        bindkey "^[^?" backward-kill-word       # Alt+Backspace: Delete previous word
        bindkey "^[[1;3A" up-line-or-history    # Alt+Up: Move to previous line or history entry
        bindkey "^[[1;3B" down-line-or-history  # Alt+Down: Move to next line or history entry
      '';
      # -------------------------------------------------------------------------------------------
      zshPlugins = lib.mkOrder 1000 ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
        source ${./p10k.zsh}
        source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
        # source ${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.zsh

        zle_highlight=('paste:none') # Disable text getting highlighted when I paste
      '';
      # -------------------------------------------------------------------------------------------
      zshOptions = lib.mkOrder 1000 ''
        # setopt extended_glob      # Enable extended globbing syntax
        setopt menu_complete       # Show completion menu on successive tab press
        setopt interactivecomments # Allow comments to be entered in interactive mode
      '';
      # -------------------------------------------------------------------------------------------
      zshFzf = lib.mkOrder 1000 ''
        export DOTFILES_DIR="${config.home.homeDirectory}/nix"
        source ${./fzf-tab.zsh}
        source ${./fzf-dash.zsh}
      '';
      # -------------------------------------------------------------------------------------------
      zshEnd = lib.mkOrder 1500 ''
        # Misc
        bindkey '^[' autosuggest-clear          # Esc: Clear autosuggestion
      '';
      # zshMac = lib.mkOrder 1000 ''
      #   '';
    in
      lib.mkMerge ([
          p10kInstantPrompt
          zshKeybindings
          zshOptions
          zshPlugins
          zshEnd
        ]
        ++ lib.optional config.programs.fzf.enable zshFzf);

    completionInit = "autoload -Uz compinit && compinit -C";
  };

  # Prevents the message "Last login: ..." from being printed when logging in
  home.file.".hushlogin".text = "";

  # Enables zsh integration by default for most modules
  home.shell.enableZshIntegration = true;
}
