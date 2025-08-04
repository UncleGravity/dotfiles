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

# ------------ diff -> delta ------------ (smells like BLOAT)
export DELTA_PAGER="less -RFX --mouse" # Fix "delta" issue where mouse scroll doesn't work in tmux
alias diff="delta"

# ------------ cd ------------
alias ..='cd ..'
alias ...='cd ../..'
alias ..3='cd ../../..'
alias ..4='cd ../../../..'
alias ..5='cd ../../../../..'

# git
alias lg="lazygit"

alias ff="fastfetch"

alias du="dua"
alias df="duf --hide-mp '/dev, *ystem*, /private*, /nix*'"

alias ts="tailscale"
alias j="just"
alias oc="bunx opencode-ai@latest"

alias no="optnix-fzf"
# export NVIM_APPNAME=lazyvim
# export NVIM_APPNAME=my-nvim
# alias nvim="NVIM_APPNAME=lazyvim nvim"
# export EDITOR=nvim
