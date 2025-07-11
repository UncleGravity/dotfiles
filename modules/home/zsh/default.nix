{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.my.zsh;
in {
  #TODO: Load secret ENVIRONMENT variables from sops-nix

  imports = [
    ./bat.nix
  ];

  options.my.zsh.enable = lib.mkEnableOption "Enable Nix-managed zsh configuration";

  config = lib.mkIf cfg.enable {

    programs.zsh = {
      enable = true;
      dotDir = ".config/zsh";

      # History -----------------------------------------------------------------------------------
      history = {
        path = "${config.xdg.dataHome}/zsh/zsh_history";
        size = 1000000; # 1_000_000
        save = 1000000; # 1_000_000
        extended = true; # save timestamp
        ignoreAllDups = true; # Keep only latest version of duplicate commands
      };

      defaultKeymap = "emacs";

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
        zshAliases = lib.mkOrder 500 ''
          source ${./aliases.zsh}
        '';
        # -------------------------------------------------------------------------------------------
        zshSecrets = lib.mkOrder 500 ''
          [ -f "${config.xdg.configHome}/zsh/secrets/home.zsh" ] && source "${config.xdg.configHome}/zsh/secrets/home.zsh"
          [ -f "${config.xdg.configHome}/zsh/secrets/work.zsh" ] && source "${config.xdg.configHome}/zsh/secrets/work.zsh"
        '';
        # -------------------------------------------------------------------------------------------
        zshPlugins = lib.mkOrder 1000 ''
          source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
          source ${./p10k.zsh}
          source ${pkgs.zsh-you-should-use}/share/zsh/plugins/you-should-use/you-should-use.plugin.zsh
          source ${pkgs.zsh-fast-syntax-highlighting}/share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh
          source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
          source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
          # source ${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.zsh

          source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
          bindkey '^[OA' history-substring-search-up
          bindkey '^[[A' history-substring-search-up
          bindkey '^[OB' history-substring-search-down
          bindkey '^[[B' history-substring-search-down

          zle_highlight=('paste:none') # Disable text getting highlighted when I paste
        '';
        # -------------------------------------------------------------------------------------------
        zshOptions = lib.mkOrder 1000 ''
          setopt nomatch            # Do not display an error message if a pattern for filename matching has no matches
          # setopt extended_glob      # Enable extended globbing syntax
          setopt menu_complete       # Show completion menu on successive tab press
          setopt interactivecomments # Allow comments to be entered in interactive mode
        '';
        # -------------------------------------------------------------------------------------------
        zshFzf = lib.mkOrder 1000 ''
          export DOTFILES_DIR="${config.home.homeDirectory}/nix"
          source ${./fzf.zsh}
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
            zshAliases
            zshSecrets
            zshOptions
            zshPlugins
            zshEnd
          ]
          ++ lib.optional config.programs.fzf.enable zshFzf);

      completionInit = "autoload -Uz compinit && compinit";
      # completionInit = "autoload -Uz compinit && compinit -u -C"; u: skip security audit, C: don't rescan fpath
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = ["--cmd cd"];
    };

    # Prevents the message "Last login: ..." from being printed when logging in
    home.file.".hushlogin".text = "";
  };
}
