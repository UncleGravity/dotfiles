# ==================================================================================================
# FZF - Defaults (nix port of fzf.zsh)
# ==================================================================================================
_: let
  # Replace find (slow) with fd (fast)
  fzfBase = "fd --strip-cwd-prefix --follow --exclude .git";
in {
  programs.fzf = {
    enable = true;

    defaultCommand = "${fzfBase} --hidden";

    ## File Search
    ## Same as default, but with preview, and with hidden files toggle
    # Widgets are zsh-scoped: home-manager renders these as sh-style `export VAR="..."`
    # lines, where `\$FZF_PROMPT` / `\"` unescape correctly. The global (non-shell-scoped)
    # options also feed nushell's env verbatim, which would keep the backslashes literal.
    fileWidget.zsh = {
      command = "${fzfBase} --hidden --type=file";
      options = [
        "--prompt '.Files> '"
        "--preview 'bat --number --color=always --line-range :500 {}'"
        "--walker-skip .git,node_modules,dist,build"
        "--tmux 80%"
        "--bind 'ctrl-/:change-preview-window(down|hidden|)'"
        "--header 'CTRL-H: Hide hidden files'"
        ''
          --bind 'ctrl-h:transform:[[ ! \$FZF_PROMPT =~ .Files ]] &&
                  echo \"change-prompt(.Files> )+reload(${fzfBase} --type file --hidden)+change-header(CTRL-H: Hide hidden files)\" ||
                  echo \"change-prompt(Files> )+reload(${fzfBase} --type file)+change-header(CTRL-H: Show hidden files)\"'
        ''
      ];
    };

    ## Directory Search
    ## Same as default, but with preview, and with hidden files toggle
    changeDirWidget.zsh = {
      command = "${fzfBase} --hidden --type=directory";
      options = [
        "--prompt '.Directories> '"
        "--preview 'eza --tree --all --color=always --icons=always --level=2 --ignore-glob .git {}'"
        "--walker-skip .git,node_modules,target"
        "--tmux 80%"
        "--bind 'ctrl-/:change-preview-window(down|hidden|)'"
        "--header 'CTRL-H: Hide hidden files'"
        ''
          --bind 'ctrl-h:transform:[[ ! \$FZF_PROMPT =~ .Directories ]] &&
                  echo \"change-prompt(.Directories> )+reload(${fzfBase} --type directory --hidden)+change-header(CTRL-H: Hide hidden files)\" ||
                  echo \"change-prompt(Directories> )+reload(${fzfBase} --type directory)+change-header(CTRL-H: Show hidden files)\"'
        ''
      ];
    };

    ## History Search
    ## Same as default, but bigger
    historyWidget.zsh.options = ["--tmux 80%"];
  };
}
