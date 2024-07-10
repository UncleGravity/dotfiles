#!/usr/bin/env bash

format_path() {
    local pane_current_path="$1"
    local pane_current_command="$2"
    local pane_tty="$3"
    local max_length=30

    pane_current_path="${pane_current_path/#$HOME/\~}"
    pane_current_path="${pane_current_path/#\/media\/psf\/Home/$(echo -e '\uF302') \~}"
    
    if [ ${#pane_current_path} -gt $max_length ]; then
        IFS='/' read -ra path_parts <<< "$pane_current_path"
        local shortened=""
        local parts_count=${#path_parts[@]}
        
        if [ $parts_count -gt 3 ]; then
            shortened="${path_parts[0]}/.../${path_parts[-2]}/${path_parts[-1]}"
        else
            for i in "${!path_parts[@]}"; do
                if [ $i -eq 0 ] || [ $i -eq $((parts_count-1)) ]; then
                    shortened+="/${path_parts[$i]}"
                else
                    shortened+="/${path_parts[$i]:0:1}"
                fi
            done
            shortened="${shortened#/}"
        fi
        
        pane_current_path="$shortened"
    fi
    
    case "$pane_current_command" in
        *zsh*|*bash*|*sh*|*fish*)
            echo "$pane_current_path"
            ;;
        sudo)
            local sudo_command="$(get_program "$pane_current_path" "$pane_current_command" "$pane_tty" | awk '{print $2}')"
            echo "$sudo_command | $pane_current_path"
            ;;
        *)
            echo "$pane_current_command | $pane_current_path"
            ;;
    esac
}

get_program() {
    local pane_current_path="$1"
    local pane_current_command="$2"
    local pane_tty="$3"
    
    pane_current_path="${pane_current_path/#$HOME/\~}"
    pane_current_path="${pane_current_path/#\/media\/psf\/Home/$(echo -e '\uF302') \~}"
    
    case "$pane_current_command" in
        *zsh*|*nvim*)
            echo "$pane_current_command"
            ;;
        *)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                full_command=$(ps -t "$pane_tty" -o command= | tail -n 1)
            else
                full_command=$(ps -t "$pane_tty" -o args= | tail -n 1)
            fi
            
            # Strip the path if the command starts with a slash
            if [[ "$full_command" == /* ]]; then
                full_command=$(echo "$full_command" | sed 's|^.*/||')
            fi
            
            echo "${full_command}"
            ;;
    esac
}

clip_command() {
    local command="$1"
    local max_length=50
    echo "$command" | sed -e 's/^[[:space:]]*//' | cut -c 1-"$max_length"
}

case "$1" in
    "--path")
        format_path "$2" "$3" "$4"
        ;;
    "--program")
        clip_command "$(get_program "$2" "$3" "$4")"
        ;;
    *)
        echo "Usage: $0 {--path|--program} [arguments]"
        exit 1
        ;;
esac