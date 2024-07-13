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

# ==================================================================================================
# FZF - Helpers
# ==================================================================================================
# tldr: Press ctrl + f to search for files, directories, grep, and tmux.
# in case i forget the keybindings

# Helper functions
_fzf_select_mode() {
    echo -e "files\ndirectories\ngrep\ntmux" | fzf --prompt="Select search mode: " --height=~50% --tmux --layout=reverse --border
}

# Fuzzy
_fzf_grep() {
    rg --hidden --color=always --line-number --no-heading --smart-case "" \
        --glob '!{node_modules,dist,build,.git}/**' \
        --glob '!*.{lock,min.js}' |
        fzf --ansi \
            --height=80% \
            --tmux 80% \
            --color "hl:-1:underline,hl+:-1:underline:reverse" \
            --delimiter : \
            --preview 'bat --color=always {1} --highlight-line {2}' \
            --preview-window 'right:66%,border-left,+{2}+3/3,~3' \
            --bind 'ctrl-/:change-preview-window(down|hidden|)'
}

_fzf_tmux() {
    local tmux_mode=$(echo -e "commands\nkeybindings" | fzf --prompt="Select tmux mode: " --height=~50% --tmux --layout=reverse --border)
    [[ -z "$tmux_mode" ]] && return

    case $tmux_mode in
        commands)
            tmux list-commands | 
                fzf --ansi \
                    --height=80% \
                    --tmux 80% \
                    --preview 'tmux list-commands {1} | bat --color=always --language=sh' \
                    --preview-window 'right:50%,border-left' \
                    --bind 'ctrl-/:change-preview-window(down|hidden|)' |
                cut -d' ' -f1
            ;;
        keybindings)
            tmux list-keys |
                awk '{$1=""; $2=""; print $0}' |
                sed 's/^  *//' |
                fzf --ansi \
                    --height=80% \
                    --tmux 80% \
                    --preview 'echo {} | bat --color=always --language=sh' \
                    --preview-window 'right:50%,border-left' \
                    --bind 'ctrl-/:change-preview-window(down|hidden|)'
            ;;
    esac
}

_select_editor() {
    echo -e "nvim\ncode\ncursor" | fzf --prompt="Select an editor: " --height=~50% --tmux 80% --layout=reverse --border
}

# Main function
fuzzy-files() {
    local mode=$(_fzf_select_mode)
    [[ -z "$mode" ]] && return

    local result=""
    case $mode in
        files)      result=$(fzf-file-widget) ;;
        directories) result=$(fzf-cd-widget) ;;
        grep)
            local selected=$(_fzf_grep)
            if [[ -n $selected ]]; then
                local file=$(echo $selected | cut -d':' -f1)
                local line=$(echo $selected | cut -d':' -f2)
                local editor=$(_select_editor)
                [[ -z "$editor" ]] && return
                
                case $editor in
                    nvim)   result="nvim +$line $file" ;;
                    code)   result="code -g $file:$line" ;;
                    cursor) result="cursor -g $file:$line" ;;
                esac
            fi
            ;;
        tmux)
            result=$(_fzf_tmux) 
            ;;
    esac

    if [[ -n $result ]]; then
        LBUFFER="$result"
        zle redisplay
    fi
    zle reset-prompt
}

zle -N fuzzy-files
bindkey '^F' fuzzy-files
