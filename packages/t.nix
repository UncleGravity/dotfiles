{
  pkgs,
  lib,
  ...
}: let
  tScript = pkgs.writeShellApplication {
    name = "t";
    runtimeInputs = with pkgs; [
      tmux
      neovim
      coreutils
      gnugrep
    ];
    text = ''
      # Tmux Utilities
      # This script provides a unified interface for managing and interacting with tmux sessions.
      action="''${1:-}"
      session_name="''${2:-}"

      case "$action" in
        ls)
          tmux list-sessions
          ;;
        edit|e)
          # Capture entire scrollback buffer and open in nvim with cursor at the end
          tmux capture-pane -JpS- | nvim - +
          ;;
        new)
          if [[ -z "$session_name" ]]; then
            session_name="$(basename "$(pwd)")"
          fi
          if [[ -n "''${TMUX:-}" ]]; then
            tmux new-session -d -s "$session_name"
            tmux switch-client -t "$session_name"
          else
            tmux new-session -A -s "$session_name"
          fi
          ;;
        a|attach)
          if [[ -z "$session_name" ]]; then
            echo "Usage: t attach <session_name>"
            exit 1
          fi
          if [[ -n "''${TMUX:-}" ]]; then
            tmux switch-client -t "$session_name"
          else
            tmux attach -t "$session_name"
          fi
          ;;
        kill)
          if [[ -z "$session_name" ]]; then
            echo "Usage: t kill <session_name>"
            exit 1
          fi
          tmux kill-session -t "$session_name"
          ;;
        switch)
          if [[ -z "$session_name" ]]; then
            echo "Usage: t switch <session_name>"
            exit 1
          fi
          if [[ -n "''${TMUX:-}" ]]; then
            tmux switch-client -t "$session_name"
          else
            echo "Not currently in a tmux session. Use 't attach <session_name>' instead."
          fi
          ;;
        ks)
          tmux kill-server
          ;;
        *)
          echo "Usage: t <action> [args]"
          echo "Actions: ls, new, attach (a), kill, switch, ks, edit (e)"
          exit 1
          ;;
      esac
    '';
  };

  completion = pkgs.writeTextFile {
    name = "_t";
    text = ''
      #compdef t

      # Completion function for t command
      function _t() {
        local -a actions sessions
        actions=(
          'ls:List all tmux sessions'
          'new:Create a new session'
          'a:Attach to a session'
          'attach:Attach to a session'
          'kill:Kill a session'
          'switch:Switch to a session'
          'ks:Kill current session and switch to another'
          'edit:Edit scrollback buffer in nvim'
          'e:Edit scrollback buffer in nvim'
        )
        sessions=(''${(f)"$(tmux list-sessions -F '#S' 2>/dev/null)"})

        _arguments \
          '1:action:->actions' \
          '*::arg:->args'

        case $state in
          actions)
            _describe -t actions 'tmux actions' actions
            ;;
          args)
            case $words[1] in
              new|a|attach|kill|switch|ks|edit|e)
                _describe -t sessions 'tmux sessions' sessions
                ;;
            esac
            ;;
        esac
      }
    '';
    destination = "/share/zsh/site-functions/_t";
  };
in
  pkgs.symlinkJoin {
    name = "t";
    paths = [tScript completion];
    meta = {
      description = "Tmux session management utility";
      platforms = lib.platforms.all;
      mainProgram = "t";
    };
  }
