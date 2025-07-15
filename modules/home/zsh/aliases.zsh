#!/usr/bin/env zsh

# ------------ ls -> eza ------------
alias ls="eza"
alias l="eza --color=always --long --icons=always --git --no-time --no-user --no-permissions --no-filesize --dereference"
alias la="eza --all --color=always --long --icons=always --git --no-time --no-user --no-permissions --no-filesize --dereference"
alias ll="eza --long --header --git --icons=always"
alias lla="eza --all --long --header --git --icons=always"
alias tree="eza -T"

# ------------ grep -> ripgrep ------------
alias grep="rg"

# ------------ cat -> bat ------------
# export BAT_PAGER="less -RF --mouse" # Fix "bat" issue where mouse scroll doesn't work in tmux
# export MANROFFOPT="-c" # Fix man page formatting issue
# export MANPAGER="sh -c 'col -bx | bat -l man -p'" # Colorize man pages (with bat)
# alias cat="bat --paging=never"
# alias -g -- --help='--help | bat --language=help --style=plain --paging=never' # Syntax highlighting for all help commands (e.g. `ls --help`)

# ------------ diff -> delta ------------ (smells like BLOAT)
export DELTA_PAGER="less -RFX --mouse" # Fix "delta" issue where mouse scroll doesn't work in tmux
alias diff="delta"

# ------------ cd ------------
alias ..='cd ..'
alias ..2='cd ../..'
alias ..3='cd ../../..'
alias ..4='cd ../../../..'
alias ..5='cd ../../../../..'

# git
alias lg="lazygit"

# ai chat
# Use XDG_CONFIG_HOME to store aichat config
# Issue: https://github.com/sigoden/aichat/issues/769
export AICHAT_CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/aichat
export CLAUDE_API_KEY=${ANTHROPIC_API_KEY}
alias ai="aichat"

alias ff="fastfetch"

alias du="dua"
alias df="duf --hide-mp '/dev, *ystem*, /private*, /nix*'"

alias ts="tailscale"
alias j="just"
alias oc="bunx opencode-ai@latest"
# export NVIM_APPNAME=lazyvim
# export NVIM_APPNAME=my-nvim
# alias nvim="NVIM_APPNAME=lazyvim nvim"
# export EDITOR=nvim
