#!/usr/bin/env bash

format_path() {
    local path="$1"
    path="${path/#$HOME/\~}"  # Replace $HOME with ~
    path="${path/#\/media\/psf\/Home/\uF302 \~}"  # Replace /media/psf/Home with Apple logo ~
    echo "$path"
}

format_path "$1"