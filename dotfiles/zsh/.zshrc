# ==================================================================================================
# Powerlevel10k Instant Prompt
# ==================================================================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==================================================================================================
# Zinit
# ==================================================================================================
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# Load Powerlevel10k theme
zinit ice depth=1 lucid
zinit light romkatv/powerlevel10k
[[ -f ${HOME}/.config/zsh/.p10k.zsh ]] && source ${HOME}/.config/zsh/.p10k.zsh

# Load other plugins with Turbo mode
zinit wait lucid for \
    Aloxaf/fzf-tab \
    MichaelAquilina/zsh-you-should-use \
    zsh-users/zsh-syntax-highlighting \
    atload"_zsh_autosuggest_start" \
        zsh-users/zsh-autosuggestions \
    zsh-users/zsh-completions

# emacs style keybindings
bindkey -e
# vim style keybindings
# bindkey -v


# ==================================================================================================
# History
# ==================================================================================================
HISTFILE=$HOME/.config/zsh/.zsh_history
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
# Keybindings
# ==================================================================================================

# completion using arrow keys (based on history)
bindkey '^[OA' history-search-backward
bindkey '^[[A' history-search-backward
bindkey '^[OB' history-search-forward
bindkey '^[[B' history-search-forward

# Option/Alt behavior
# bindkey "^[b" backward-word # Alt+b
bindkey "^[[1;3D" backward-word # Alt+Left
# bindkey "^[f" forward-word # Alt+f
bindkey "^[[1;3C" forward-word # Alt+Right
bindkey "^[^?" backward-kill-word # Alt+Backspace

bindkey '^[' autosuggest-clear # Esc

# ==================================================================================================
# Options
# ==================================================================================================
# Set options
setopt autocd             # Automatically change to a directory just by typing its name
# setopt extended_glob      # Enable extended globbing syntax
setopt nomatch            # Do not display an error message if a pattern for filename matching has no matches
setopt menu_complete       # Show completion menu on successive tab press
setopt interactivecomments # Allow comments to be entered in interactive mode

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

# Aliases
alias ls="eza"
alias l="eza -alh --git --hyperlink"
alias ll="eza -lh --git --hyperlink"
alias tree="eza -T"
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

export BAT_PAGER="less -RFX --mouse"

alias please='sudo'
alias homeconfig="sudo nvim /etc/nixos/home.nix"
alias zshconfig="sudo nvim /etc/nixos/dotfiles/zsh/.zshrc"
alias zshrst='source $HOME/.config/zsh/.zshrc'

alias ya="yazi"

alias zj="zellij"
alias zjc="zellij --layout compact"

alias dbox="distrobox"

case "$(uname -s)" in
  Darwin)
    # echo 'Mac OS X'
    [ -f "${0:a:h}/.macos.zsh" ] && source "${0:a:h}/.macos.zsh"
    ;;
  Linux)
    #
    ;;
  CYGWIN* | MINGW32* | MSYS* | MINGW*)
    # echo 'MS Windows'
    ;;
  *)
    # echo 'Other OS'
    ;;
esac


# ENV Variables
export ANTHROPIC_API_KEY="nonono"
export OPENAI_API_KEY="nonono"

# ==================================================================================================
# Completions (LAST SECTION)
# ==================================================================================================
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=*' # case insensitive matching
zstyle ':completion:*:git-checkout:*' sort false # disable sort when completing `git checkout`
zstyle ':completion:*:descriptions' format '[%d]' # set descriptions format to enable group support
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} # colorize the completion list
zstyle ':completion:*' menu no # disable menu so that we can use fzf instead
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath' # preview directory contents
zstyle ':fzf-tab:*' switch-group '<' '>' # switch group using `<` and `>`
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup # use tmux popup for fzf-tab, if in tmux
zstyle ':completion:*' rehash true 

# Keep this at the end of the file
# This block ensures that the completion cache is properly set up and updated
[[ ! -d "$HOME/.cache/zsh" ]] && mkdir -p "$HOME/.cache/zsh" # Create zsh cache dir
autoload -Uz compinit # Load the completion system

compinit -d "$HOME/.cache/zsh/zcompdump"

zinit cdreplay -q # recommended by zinit
