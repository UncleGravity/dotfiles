#!/usr/bin/env bash

get_program() {
    local path="$1"
    local pane_command="$2"
    local pane_tty="$3"
    
    # Replace $HOME with ~ and /media/psf/Home with Apple logo ~
    path="${path/#$HOME/\~}"
    path="${path/#\/media\/psf\/Home/$(echo -e '\uF302') \~}"
    
    # Check if the command is one of the specified shells
    case "$pane_command" in
        *zsh*)
            echo "$pane_command"
            ;;
        *)
            # For non-shell commands, get the full command
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                full_command=$(ps -t "$pane_tty" -o command= | tail -n 1)
            else
                # Linux
                full_command=$(ps -t "$pane_tty" -o args= | tail -n 1)
            fi
            
            # Remove leading whitespace and limit to 50 characters
            full_command=$(echo "$full_command" | sed -e 's/^[[:space:]]*//' | cut -c 1-50)
            
            # echo "${full_command} | $path"
            echo "${full_command}"
            ;;
    esac
}

get_program "$1" "$2" "$3"