# Helper functions
_fzf_select_mode() {
    echo -e "files\ndirectories\ngrep" | fzf --prompt="Select search mode: " --height=~50% --tmux --layout=reverse --border
}

_fzf_files() {
    fd --type f --hidden --follow --exclude .git --exclude node_modules --exclude dist --exclude build | 
        fzf --ansi \
            --height=80% \
            --tmux 80% \
            --preview 'bat --color=always --style=numbers {}' \
            --preview-window 'right:66%,border-left' \
            --bind 'ctrl-/:change-preview-window(down|hidden|)'
}

_fzf_directories() {
    fd --type d --hidden --follow --exclude .git --exclude node_modules --exclude dist --exclude build | 
        fzf --ansi \
            --height=80% \
            --tmux 80% \
            --preview 'eza -1 --color=always {}' \
            --preview-window 'right:66%,border-left' \
            --bind 'ctrl-/:change-preview-window(down|hidden|)'
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

# Not fuzzy, but more efficient. Uses ripgrep for filtering, not fzf.
# _fzf_grep() {
#     local RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case \
#     --hidden --glob '!{.git,node_modules,dist,build}/**'"
    
#     local INITIAL_QUERY="${*:-}"
#     fzf --ansi --disabled --query "$INITIAL_QUERY" \
#         --bind "start:reload:$RG_PREFIX {q}" \
#         --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
#         --delimiter : \
#         --preview 'bat --color=always {1} --highlight-line {2}' \
#         --preview-window 'right:66%,border-left,+{2}+3/3,~3' \
#         --height=80% \
#         --tmux 80% \
#         --bind 'enter:become(echo {1}:{2})'
# }

_select_editor() {
    echo -e "nvim\ncode\ncursor" | fzf --prompt="Select an editor: " --height=~50% --tmux 80% --layout=reverse --border
}

# Main function
fuzzy-files() {
    local mode=$(_fzf_select_mode)
    [[ -z "$mode" ]] && return

    local result=""
    case $mode in
        files)      result=$(_fzf_files) ;;
        directories) result=$(_fzf_directories) ;;
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
    esac

    if [[ -n $result ]]; then
        LBUFFER="$result"
        zle redisplay
    fi
    zle reset-prompt
}

zle -N fuzzy-files
bindkey '^F' fuzzy-files
