# emacs style keybindings
bindkey -e
# vim style keybindings
# bindkey -v

# ==================================================================================================
# Powerlevel10k
# ==================================================================================================

# Instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Get the prompt
# source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme # MACOS
source source-p10k # THE NIX WAY
source ${HOME}/.config/zsh/.p10k.zsh

# ==================================================================================================
# Plugins
# ==================================================================================================
source $HOME/.config/zsh/plugins/you-should-use.plugin.zsh
# source ${HOME}/.config/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# source ${HOME}/.config/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh


# ==================================================================================================
# History
# ==================================================================================================
# Enable command history
# HISTORY. Run man zshoptions
HISTFILE=$HOME/.zsh_history
HISTSIZE=1000000
SAVEHIST=$HISTSIZE
setopt EXTENDED_HISTORY          # Write the history file in the ':start:elapsed;command' format.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history.
setopt HIST_FIND_NO_DUPS         # Do not display a previously found event.
setopt HIST_IGNORE_ALL_DUPS      # Delete an old recorded event if a new event is a duplicate.
setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again.
setopt HIST_IGNORE_SPACE         # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS         # Do not write a duplicate event to the history file.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_VERIFY               # When retrieving a command from history, show the command but do not execute it until the Enter key is pressed again

# ==================================================================================================
# Completions
# ==================================================================================================
[[ ! -d "$HOME/.cache/zsh" ]] && mkdir -p "$HOME/.cache/zsh" # if the directory does not exist, create it
compinit -d "$HOME/.cache/zsh/zcompdump" # Set custom zcompdump location
autoload -Uz compinit && compinit # Enable completions

# ==================================================================================================
# Keybindings
# ==================================================================================================

# completion using arrow keys (based on history)
bindkey '^[OA' history-search-backward
bindkey '^[[A' history-search-backward
bindkey '^[OB' history-search-forward
bindkey '^[[B' history-search-forward

bindkey "^[b" backward-word
bindkey "^[[1;3D" backward-word
bindkey "^[f" forward-word
bindkey "^[[1;3C" forward-word
bindkey "^[^?" backward-kill-word

# ==================================================================================================
# Options
# ==================================================================================================
# Set options
setopt autocd             # Automatically change to a directory just by typing its name
# setopt extended_glob      # Enable extended globbing syntax
setopt nomatch            # Do not display an error message if a pattern for filename matching has no matches
setopt menu_complete       # Show completion menu on successive tab press
setopt interactivecomments # Allow comments to be entered in interactive mode


# Enable fzf key bindings and completion
# [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)


# Aliases
alias ls="eza"
alias l="eza -alh"
alias ll"eza -1"
alias tree="eza -T"
#alias l="ls -alh"
#alias ll='ls -lh'
#alias la='ls -lAh'
# alias ..='cd ..'
# alias ...='cd ../..'

alias please='sudo'
alias zshconfig="sudo nvim /etc/nixos/dotfiles/zsh/.zshrc"
alias zshrst='source $HOME/.config/zsh/.zshrc'
alias homeconfig="sudo nvim /etc/nixos/home.nix"
# case "$(uname -s)" in

# Darwin)
# 	# echo 'Mac OS X'
# 	alias ls='ls -G'
# 	;;

# Linux)
# 	alias ls='ls --color=auto'
# 	;;

# CYGWIN* | MINGW32* | MSYS* | MINGW*)
# 	# echo 'MS Windows':
# 	;;
# *)
# 	# echo 'Other OS'
# 	;;
# esac


# ENV Variables
export ANTHROPIC_API_KEY="nonono"
export OPENAI_API_KEY="nonono"
