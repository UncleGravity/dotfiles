#!/usr/bin/env zsh

# ==================================================================================================
# FZF - Defaults
# ==================================================================================================

# Replace find (slow) with fd (fast)
export _FZF_BASE_COMMAND="fd --strip-cwd-prefix --follow --exclude .git"
export FZF_DEFAULT_COMMAND="${_FZF_BASE_COMMAND} --hidden"
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND} --type=file"
export FZF_ALT_C_COMMAND="${FZF_DEFAULT_COMMAND} --type=directory"

## Directory Search
## Same as default, but with preview, and with hidden files toggle
export FZF_ALT_C_OPTS="
  --prompt '.Directories> '
  --preview 'eza --tree --all --color=always --icons=always --level=2 --ignore-glob .git {}'
  --walker-skip .git,node_modules,target
  --tmux 80%
  --bind 'ctrl-/:change-preview-window(down|hidden|)'
  --header 'CTRL-H: Hide hidden files'
  --bind 'ctrl-h:transform:[[ ! \$FZF_PROMPT =~ .Directories ]] &&
          echo \"change-prompt(.Directories> )+reload(${_FZF_BASE_COMMAND} --type directory --hidden)+change-header(CTRL-H: Hide hidden files)\" ||
          echo \"change-prompt(Directories> )+reload(${_FZF_BASE_COMMAND} --type directory)+change-header(CTRL-H: Show hidden files)\"'
"

## File Search
## Same as default, but with preview, and with hidden files toggle
export FZF_CTRL_T_OPTS="
  --prompt '.Files> '
  --preview 'bat --number --color=always --line-range :500 {}'
  --walker-skip .git,node_modules,dist,build
  --tmux 80%
  --bind 'ctrl-/:change-preview-window(down|hidden|)'
  --header 'CTRL-H: Hide hidden files'
  --bind 'ctrl-h:transform:[[ ! \$FZF_PROMPT =~ .Files ]] &&
          echo \"change-prompt(.Files> )+reload(${_FZF_BASE_COMMAND} --type file --hidden)+change-header(CTRL-H: Hide hidden files)\" ||
          echo \"change-prompt(Files> )+reload(${_FZF_BASE_COMMAND} --type file)+change-header(CTRL-H: Show hidden files)\"'
"

## History Search
## Same as default, but bigger
export FZF_CTRL_R_OPTS="--tmux 80%"
