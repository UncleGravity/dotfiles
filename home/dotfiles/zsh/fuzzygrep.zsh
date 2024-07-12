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
            --preview-window 'right:66%,border-left'
}

_fzf_directories() {
    fd --type d --hidden --follow --exclude .git --exclude node_modules --exclude dist --exclude build | 
        fzf --ansi \
            --height=80% \
            --tmux 80% \
            --preview 'eza -1 --color=always {}' \
            --preview-window 'right:66%,border-left'
}

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
            --preview-window 'right:66%,border-left,+{2}+3/3,~3'
}

_select_editor() {
    echo -e "nvim\ncode\ncursor" | fzf --prompt="Select an editor: " --height=~50% --tmux 80% --layout=reverse --border
}

# Main function
fzrg() {
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

zle -N fzrg
bindkey '^F' fzrg