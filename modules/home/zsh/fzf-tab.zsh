#!/usr/bin/env zsh

# ==================================================================================================
# FZF-TAB
# ==================================================================================================
# General Completions Formatting
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=*' # case insensitive matching
zstyle ':completion:*:git-checkout:*' sort false                       # disable sort when completing `git checkout`
zstyle ':completion:*' list-colors $(echo "$LS_COLORS" | tr ':' ' ')   # colorize the completion list
zstyle ':completion:*' menu no                                         # disable default menu so that we can use fzf instead

## Show a preview of the selected item
# -------------------------------------------------------------------------------------------------

### general:
zstyle ':completion:*:descriptions' format '[%d]' # group completions by type
zstyle ':fzf-tab:*' switch-group '<' '>'          # switch group using `<` and `>`
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup    # use tmux popup for fzf-tab, if in tmux

### Formatting:
zstyle ':fzf-tab:*' popup-min-size 200 200 # minimum size, apply to all commands
# zstyle ':fzf-tab:complete:diff:*' popup-min-size 80 12 # only apply to 'diff' (for example)

### cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath' # preview directory contents

### environment variables
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
  fzf-preview 'echo ${(P)word}'

### systemd (Linux)
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'

### kill
# give a preview of commandline arguments when completing `kill`
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm"
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview \
  '[[ $group == "[process ID]" ]] && ps -p $word -o pid,user,comm,args'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags \
  --preview-window=down:3:wrap \
  --multi \
  --bind='ctrl-a:toggle-all' \
  --bind='tab:toggle+down'

### code
zstyle ':fzf-tab:complete:(hx|nvim|zed|code|cursor|bat):*' \
  fzf-preview 'bat --color=always --style=numbers $realpath'
zstyle ':fzf-tab:complete:(nvim|code|cursor|bat):*' fzf-flags \
  --multi \
  --bind='ctrl-a:toggle-all' \
  --bind='tab:toggle+down'
