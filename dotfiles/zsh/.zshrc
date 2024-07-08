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
HISTSIZE=1_000_000
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

# Function to trim leading spaces and add to history
# function zshaddhistory() {
#     setopt local_options extended_glob
#     print -Sr -- ${1%%[[:space:]]##}
#     return 1  # suppress default behavior
# }

# ==================================================================================================
# Keybindings
# ==================================================================================================

# Word delimiters
# This section configures how Zsh treats word boundaries, which affects navigation and text manipulation
autoload -U select-word-style
select-word-style bash  # Use Bash-style word definitions
zstyle ':zle:*' word-chars " _-./;@"  # Define additional characters to be treated as part of words
zstyle ':zle:*' word-style unspecified

# History search
# These bindings allow searching through command history using arrow keys
bindkey '^[OA' history-search-backward  # Up arrow (some terminals)
bindkey '^[[A' history-search-backward  # Up arrow (other terminals)
bindkey '^[OB' history-search-forward   # Down arrow (some terminals)
bindkey '^[[B' history-search-forward   # Down arrow (other terminals)

# Option/Alt key navigation
# These keybindings enhance text navigation using Option/Alt key combinations
bindkey "^[[1;3D" backward-word         # Alt+Left: Move cursor to previous word
bindkey "^[[1;3C" forward-word          # Alt+Right: Move cursor to next word
bindkey "^[^?" backward-kill-word       # Alt+Backspace: Delete previous word

# Misc
bindkey '^[' autosuggest-clear          # Esc: Clear autosuggestion

# Note: Some keybindings are commented out but kept for reference
# bindkey "^[b" backward-word           # Alt+b (alternative for backward-word)
# bindkey "^[f" forward-word            # Alt+f (alternative for forward-word)

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

# ==================================================================================================
# Aliases
# ==================================================================================================

# USEFUL COMMANDS
# ctrl + r : search through command history (with fzf).
# Option + c : search folders/subfolders (with fzf). Press enter to cd into it.
# fd <query> : display FILES/FOLDERS that match the given query
# rg <query> : search for a <query> INSIDE file CONTENTS (will recursively search all files)
# rg <query> -g '<glob>' : same as previous, but only search in FILES matching the given <glob>
# rg <query> -l : list all files that contain the given <query>
# rg <query> --json | delta : add syntax highlighting to the output of the given <query> (for code searching)
# tree : display recursive tree view starting from current directory

# ------------ ls -> eza ------------
alias ls="eza"
alias l="eza -alh --git"
alias ll="eza -lh --git"
alias tree="eza -T"

# ------------ grep -> ripgrep ------------
alias grep="rg"

# ------------ cat -> bat ------------
export BAT_PAGER="less -RFX --mouse" # Fix "bat" issue where mouse scroll doesn't work in tmux
export MANPAGER="sh -c 'col -bx | bat -l man -p'" # Colorize man pages (with bat)
export MANROFFOPT="-c" # Fix man page formatting issue
alias cat="bat --paging=never"
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain --paging=never' # Syntax highlighting for all help commands (e.g. `ls --help`)

# ------------ diff -> delta ------------ (smells like BLOAT)
export DELTA_PAGER="less -RFX --mouse" # Fix "delta" issue where mouse scroll doesn't work in tmux
alias diff="delta"

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

alias zshconfig="sudo nvim /etc/nixos/dotfiles/zsh/.zshrc"
alias zshrst='source $HOME/.config/zsh/.zshrc'

# yazi
alias ya="yazi"

# Tmux aliases
# alias t="tmux new-session -A -s $(basename $(pwd))"
alias t="tmux"
alias tn="tmux new-session -A -s"   # Create a new tmux session
alias ta="tmux attach -t"           # Attach to an existing tmux session
alias tl="tmux list-sessions"       # List all tmux sessions
alias tk="tmux kill-session -t"     # Kill a specific tmux session
alias ts="tmux switch-client -t"    # Switch to a specific tmux session
alias tks="tmux kill-server"        # Kill the tmux server and all sessions

alias zj="zellij"
alias zjc="zellij --layout compact"

alias ff="fastfetch"

# ==================================================================================================
# OS Specific
# ==================================================================================================
case "$(uname -s)" in
  Darwin)
    # echo 'Mac OS X'
    [ -f "${0:a:h}/.macos.zsh" ] && source "${0:a:h}/.macos.zsh"
    ;;
  Linux)
    alias dbox="distrobox"
    ;;
  CYGWIN* | MINGW32* | MSYS* | MINGW*)
    # echo 'MS Windows'
    ;;
  *)
    # echo 'Other OS'
    ;;
esac

# ==================================================================================================
# ENV Variables TODO: move to keychain
# ==================================================================================================
export ANTHROPIC_API_KEY="nonono"
export OPENAI_API_KEY="nonono"

# ==================================================================================================
# Completions (KEEP AT THE END OF FILE)
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
