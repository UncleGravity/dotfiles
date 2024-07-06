#!/usr/bin/env bash

# format_path() {
#     local path="$1"
#     local pane_command="$2"

#     # Replace $HOME with ~ and /media/psf/Home with Apple logo ~
#     path="${path/#$HOME/\~}"
#     path="${path/#\/media\/psf\/Home/$(echo -e '\uF302') \~}"
    
#     # Check if the command is one of the specified shells
#     case "$pane_command" in
#         *zsh*|*bash*|*sh*|*fish*)
#             echo "$path"
#             ;;
#         *)
#             echo "$pane_command | $path"
#             ;;
#     esac
# }

# format_path "$1" "$2"

format_path() {
    local path="$1"
    local pane_command="$2"
    local max_length=30

    # Replace $HOME with ~ and /media/psf/Home with Apple logo ~
    path="${path/#$HOME/\~}"
    path="${path/#\/media\/psf\/Home/$(echo -e '\uF302') \~}"
    
    # Shorten path if it's longer than max_length
    if [ ${#path} -gt $max_length ]; then
        # Split path into array
        IFS='/' read -ra path_parts <<< "$path"
        
        # Keep the first part (usually ~ or /) and the last two parts
        local shortened=""
        local parts_count=${#path_parts[@]}
        
        if [ $parts_count -gt 3 ]; then
            shortened="${path_parts[0]}/.../${path_parts[-2]}/${path_parts[-1]}"
        else
            # Shorten middle parts
            for i in "${!path_parts[@]}"; do
                if [ $i -eq 0 ] || [ $i -eq $((parts_count-1)) ]; then
                    shortened+="/${path_parts[$i]}"
                else
                    shortened+="/${path_parts[$i]:0:1}"
                fi
            done
            shortened="${shortened#/}"
        fi
        
        path="$shortened"
    fi
    
    # Check if the command is one of the specified shells
    case "$pane_command" in
        *zsh*|*bash*|*sh*|*fish*)
            echo "$path"
            ;;
        *)
            echo "$pane_command | $path"
            ;;
    esac
}

format_path "$1" "$2"