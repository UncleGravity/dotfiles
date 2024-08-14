# ==================================================================================================
# Profiling Start (see end of file)
# ==================================================================================================
# zmodload zsh/zprof

# ==================================================================================================
# Zinit - Install and Update
# ==================================================================================================

# Install Zinit if it's not already installed
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# (optional) Update Zinit and plugins (weekly)
ZINIT_LAST_UPDATE_FILE="${ZINIT_HOME}/.zinit_last_update"
ZINIT_UPDATE_INTERVAL=$((7 * 24 * 60 * 60))  # 7 days in seconds

if [[ ! -f "$ZINIT_LAST_UPDATE_FILE" ]] || (( $(date +%s) - $(cat "$ZINIT_LAST_UPDATE_FILE") > ZINIT_UPDATE_INTERVAL )); then
    echo "Updating Zinit and plugins..."
  zinit self-update
    zinit update --all
    date +%s > "$ZINIT_LAST_UPDATE_FILE"
fi

# ==================================================================================================
# DEV
# ==================================================================================================
eval "$(direnv hook zsh)" # Without this, direnv will not work (actually I'll just set this on home.nix)

# ==================================================================================================
# Powerlevel10k Instant Prompt
# ==================================================================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==================================================================================================
# Plugins
# ==================================================================================================

# Load Powerlevel10k theme
zinit for \
  depth=1 \
  lucid \
  atload="[[ -f \${ZDOTDIR}/p10k.zsh ]] && source \${ZDOTDIR}/p10k.zsh" \
  romkatv/powerlevel10k

# Load other plugins with Turbo mode
zinit light MichaelAquilina/zsh-you-should-use
zinit light Aloxaf/fzf-tab
zinit light zsh-users/zsh-completions
zinit wait lucid for \
  atload"_zsh_autosuggest_start" \
  zsh-users/zsh-autosuggestions \
  zdharma-continuum/fast-syntax-highlighting # This breaks delimiters if not deferred

# ==================================================================================================
# History
# ==================================================================================================
HISTFILE="${ZDOTDIR}/.zsh_history"
HISTSIZE=1_000_000
SAVEHIST=$HISTSIZE
setopt EXTENDED_HISTORY          # Write the history file in the ':start:elapsed;command' format.
# setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history.
setopt HIST_FIND_NO_DUPS         # Do not display a previously found event.
# setopt HIST_IGNORE_ALL_DUPS      # Delete an old recorded event if a new event is a duplicate.
setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again.
setopt HIST_IGNORE_SPACE         # Do not record an event starting with a space.
# setopt HIST_SAVE_NO_DUPS         # Do not write a duplicate event to the history file.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_VERIFY               # When retrieving a command from history, show the command but do not execute it until the Enter key is pressed again

# ==================================================================================================
# Keybindings
# ==================================================================================================

# emacs style keybindings
bindkey -e
# vim style keybindings
# bindkey -v

# Word delimiters
# This section configures how Zsh treats word boundaries, which affects navigation and text manipulation
autoload -U select-word-style; select-word-style bash  # Use Bash-style word definitions
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
bindkey "^[[1;3A" up-line-or-history    # Alt+Up: Move to previous line or history entry
bindkey "^[[1;3B" down-line-or-history  # Alt+Down: Move to next line or history entry

# Misc
bindkey '^[' autosuggest-clear          # Esc: Clear autosuggestion

# ==================================================================================================
# FZF
# ==================================================================================================

# Set up default fzf key bindings and fuzzy completion
source <(fzf --zsh)
# export FZF_DEFAULT_OPTS='--tmux' # I think this is causing issue
 
# MY FZF CONFIG 
# -------------------------------------------------------------------------------------
[ -f "$HOME/.config/zsh/fzf.zsh" ] && source "$HOME/.config/zsh/fzf.zsh"

# ==================================================================================================
# Options
# ==================================================================================================
# Set options
setopt autocd             # Automatically change to a directory just by typing its name
# setopt extended_glob      # Enable extended globbing syntax
setopt nomatch            # Do not display an error message if a pattern for filename matching has no matches
setopt menu_complete       # Show completion menu on successive tab press
setopt interactivecomments # Allow comments to be entered in interactive mode

# ==================================================================================================
# Aliases
# ==================================================================================================

# USEFUL COMMANDS
# ctrl + r : search through command history (with fzf).
# ctrl + t : search through files/folders in current directory (with fzf).
# Option + c : search folders/subfolders (with fzf). Press enter to cd into it.
# fd <query> : display FILES/FOLDERS that match the given query
# rg <query> : search for a <query> INSIDE file CONTENTS (will recursively search all files)
# rg <query> -g '<glob>' : same as previous, but only search in FILES matching the given <glob>
# rg <query> -l : list all files that contain the given <query>
# rg <query> --json | delta : add syntax highlighting to the output of the given <query> (for code searching)
# tree : display recursive tree view starting from current directory

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
export BAT_PAGER="less -RF --mouse" # Fix "bat" issue where mouse scroll doesn't work in tmux
export MANPAGER="sh -c 'col -bx | bat -l man -p'" # Colorize man pages (with bat)
export MANROFFOPT="-c" # Fix man page formatting issue
alias cat="bat --paging=never"
alias -g -- --help='--help | bat --language=help --style=plain --paging=never' # Syntax highlighting for all help commands (e.g. `ls --help`)

# ------------ diff -> delta ------------ (smells like BLOAT)
export DELTA_PAGER="less -RFX --mouse" # Fix "delta" issue where mouse scroll doesn't work in tmux
alias diff="delta"

# ------------ yazi ------------
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# ------------ cd ------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

alias zshconfig="nvim $HOME/Documents/.dotfiles/"
alias zshrst="source ${ZDOTDIR:-$HOME/.config/zsh}/.zshrc"

# git
alias lg="lazygit"

# Tmux aliases
# alias t="tmux new-session -A -s $(basename $(pwd))"
alias t="tmux"
alias tn="tmux new-session -A -s"   # Create a new tmux session
alias ta="tmux attach -t"           # Attach to an existing tmux session
alias tl="tmux list-sessions"       # List all tmux sessions
alias tk="tmux kill-session -t"     # Kill a specific tmux session
alias ts="tmux switch-client -t"    # Switch to a specific tmux session
alias tks="tmux kill-server"        # Kill the tmux server and all sessions

# [ -f "$HOME/.config/zsh/tmux.zsh" ] && source "$HOME/.config/zsh/tmux.zsh"

alias zj="zellij"
alias zjc="zellij --layout compact"

alias ff="fastfetch"

alias nvim="NVIM_APPNAME=lazyvim nvim"

# ==================================================================================================
# OS Specific
# ==================================================================================================
case "$(uname -s)" in
  Darwin)
    export XDG_CONFIG_HOME="$HOME/.config"
    eval "$(/opt/homebrew/bin/brew shellenv)"
    
    [ -f "${HOME}/.config/zsh/macos/vm.zsh" ] && source "${HOME}/.config/zsh/macos/vm.zsh"
    [ -f "${HOME}/.config/zsh/macos/dev.zsh" ] && source "${HOME}/.config/zsh/macos/dev.zsh"
    ;;
  Linux)
    alias dbox="distrobox"
    # Aliases for GNOME GUI control
    alias gui-off="sudo systemctl set-default multi-user.target && sudo systemctl isolate multi-user.target"
    alias gui-on="sudo systemctl set-default graphical.target && sudo systemctl isolate graphical.target"
    ;;
  CYGWIN* | MINGW32* | MSYS* | MINGW*)
    # echo 'MS Windows'
    ;;
  *)
    # echo 'Other OS'
    ;;
esac

# ==================================================================================================
# SECRETS
# ==================================================================================================
[ -f "$HOME/.config/zsh/secrets/_decrypt.sh" ] && source "$HOME/.config/zsh/secrets/_decrypt.sh"

# ==================================================================================================
# Completions (KEEP AT THE END OF FILE)
# ==================================================================================================
# ie. what happens when you press <TAB>

# Completions Formatting
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=*' # case insensitive matching
zstyle ':completion:*:git-checkout:*' sort false # disable sort when completing `git checkout`
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} # colorize the completion list
zstyle ':completion:*' menu no # disable default menu so that we can use fzf instead

# FZF-TAB behavior defined in fzf.zsh

# -------------------------------------------------------------------------------------------------

zstyle ':completion:*' rehash true # automatically update cache (keep completions up to date)

# Load missing completions for macOS
if [[ "$(uname)" == "Darwin" ]]; then
  [[ -d /opt/homebrew/share/zsh/site-functions ]] && fpath+=(/opt/homebrew/share/zsh/site-functions) # Homebrew
  [[ -d /Applications/Cursor.app/Contents/Resources/app/resources/completions/zsh ]] && fpath+=(/Applications/Cursor.app/Contents/Resources/app/resources/completions/zsh) # Cursor
  [[ -d /Applications/kitty.app/Contents/Resources/kitty/shell-integration/zsh/completions ]] && fpath+=(/Applications/kitty.app/Contents/Resources/kitty/shell-integration/zsh/completions) # Kitty
else
  # Load missing completions for ubuntu!
  [[ -d /usr/share/zsh/site-functions ]] && fpath+=/usr/share/zsh/site-functions
  [[ -d /usr/share/zsh/vendor-completions ]] && fpath+=/usr/share/zsh/vendor-completions
fi

# Load custom completions
fpath=(~/.config/zsh/auto-completions $fpath) # automatic collection of completions for all home-manager packages
fpath=(~/.config/zsh/completions $fpath) # manual collection of completions

# Keep this at the end of the file
# This block ensures that the completion cache is properly set up and updated
autoload -Uz compinit
compinit -d "${ZDOTDIR}/.zcompdump"

eval "$(zoxide init --cmd cd zsh)" # this goes after compinit, according to the docs

## Additional completions for commands that don't have them
## This generates completions using the respective --help page
compdef _gnu_generic fzf # https://github.com/junegunn/fzf/issues/3349
compdef _gnu_generic lazygit
compdef _gnu_generic file
compdef _gnu_generic devenv
# compdef _gnu_generic SOME_OTHER_COMMAND

# Weird issue with delta completion, I have to load it manually
compdef _delta delta

zinit cdreplay -q # recommended by zinit

# ==================================================================================================
# Profiling End
# ==================================================================================================
# zprof
