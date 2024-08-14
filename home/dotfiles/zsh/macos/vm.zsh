#!/usr/bin/env zsh

# VM Utilities
# This script provides a unified interface for managing and interacting with virtual machines.

# Usage:
#   vm <action> [args]
#
# Actions:
#   ls                     List all VMs
#   start <vm_name>        Start a VM
#   stop <vm_name>         Stop a VM
#   pause <vm_name>        Pause a VM
#   resume <vm_name>       Resume a paused VM
#   restart <vm_name>      Restart a VM
#   shell <vm_name>        Open a shell in a VM
#   code <vm_name> [-d]    Open VS Code for a VM (use -d for dotfiles)
#   cursor <vm_name> [-d]  Open Cursor for a VM (use -d for dotfiles)
#   run <vm_name> <cmd>    Run a command in a VM
#
# Examples:
#   vm ls
#   vm start ubuntu
#   vm shell nixos
#   vm code ubuntu -d
#   vm run ubuntu ls -l /home

# VM Configuration
# Format: [vm_name]="username@hostname:/remote/base/path"
typeset -A VM_CONFIG
VM_CONFIG=(
  [ubuntu]="parallels@uvm.local:/media/psf/Home/"
  [nixos]="angel@nixos:/media/psf/Home/"
)

# Helper function to get the remote path for a VM
# Args:
#   $1: VM name
function _vm_get_remote_path() {
  local vm_name="$1"
  local current_local_path="$(pwd)"
  local vm_info="${VM_CONFIG[$vm_name]}"
  local remote_base_path="${vm_info#*:}"
  
  if [[ $current_local_path == "$HOME" ]]; then
    echo "${remote_base_path%/}"
  elif [[ $current_local_path == "/Users/"* ]]; then
    echo "${remote_base_path}${current_local_path#/Users/*/}"
  else
    echo "${remote_base_path}${current_local_path#$HOME}"
  fi
}

# Helper function to run a command on a remote VM
# Args:
#   $1: VM name
#   $@: Command to run
function _vm_run_command() {
  local vm_name="$1"
  shift
  local vm_info="${VM_CONFIG[$vm_name]}"
  local remote_user="${vm_info%%@*}"
  local remote_host="${vm_info#*@}"
  remote_host="${remote_host%%:*}"
  
  ssh -t "$remote_user@$remote_host" "$@"
}

# Main vm function
function vm() {
  local action="$1"
  local vm_name="$2"
  shift 2

  case "$action" in
    ls)
      prlctl list -a
      ;;
    start|stop|pause|resume|restart)
      [[ -z "$vm_name" ]] && { echo "Usage: vm $action <vm_name>"; return 1; }
      prlctl $action $vm_name
      ;;
    shell)
      [[ -z "$vm_name" ]] && { echo "Usage: vm shell <vm_name>"; return 1; }
      local remote_path=$(_vm_get_remote_path "$vm_name")
      _vm_run_command "$vm_name" "cd $remote_path && exec \$SHELL -l"
      ;;
    code|cursor)
      [[ -z "$vm_name" ]] && { echo "Usage: vm $action <vm_name> [-d]"; return 1; }
      local remote_path=$(_vm_get_remote_path "$vm_name")
      local vm_info="${VM_CONFIG[$vm_name]}"
      local remote_user="${vm_info%%@*}"
      local remote_host="${vm_info#*@}"
      remote_host="${remote_host%%:*}"
      local dotfiles_path="/home/$remote_user/.dotfiles"
      local target_path="$remote_path"
      [[ "$1" == "-d" ]] && target_path="$dotfiles_path"
      $action --folder-uri "vscode-remote://ssh-remote+$remote_user@$remote_host$target_path" --new-window
      ;;
    run)
      [[ -z "$vm_name" ]] && { echo "Usage: vm run <vm_name> <command>"; return 1; }
      [[ -z "$1" ]] && { echo "Please specify a command to run"; return 1; }
      _vm_run_command "$vm_name" "$@"
      ;;
    *)
      echo "Usage: vm <action> [args]"
      echo "Actions: ls, start, stop, pause, resume, restart, shell, code, cursor, run"
      return 1
      ;;
  esac
}