#!/usr/bin/env zsh

# Tmux Utilities
# This script provides a unified interface for managing and interacting with tmux sessions.

# Usage:
#   t <action> [args]
#
# Actions:
#   ls                     List all tmux sessions
#   edit|e                 Edit the tmux scrollback buffer in nvim
#   new [session_name]     Create a new tmux session
#   a|attach [session_name] Attach to a tmux session
#   kill [session_name]    Kill a specific tmux session
#   switch [session_name]  Switch to a specific tmux session
#   ks                     Kill the tmux server and all sessions
#
# Examples:
#   t ls
#   t new my_session
#   t a my_session
#   t kill my_session

function t() {
  local action="$1"
  local session_name="$2"

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
      if [[ -n "$TMUX" ]]; then
        tmux new-session -d -s "$session_name"
        tmux switch-client -t "$session_name"
      else
        tmux new-session -A -s "$session_name"
      fi
      ;;
    a|attach)
      if [[ -z "$session_name" ]]; then
        echo "Usage: t attach <session_name>"
        return 1
      fi
      if [[ -n "$TMUX" ]]; then
        tmux switch-client -t "$session_name"
      else
        tmux attach -t "$session_name"
      fi
      ;;
    kill)
      if [[ -z "$session_name" ]]; then
        echo "Usage: t kill <session_name>"
        return 1
      fi
      tmux kill-session -t "$session_name"
      ;;
    switch)
      if [[ -z "$session_name" ]]; then
        echo "Usage: t switch <session_name>"
        return 1
      fi
      if [[ -n "$TMUX" ]]; then
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
      return 1
      ;;
  esac
}

# Alias 't' without arguments to create or attach to a session named after the current directory
# alias t='t new'
