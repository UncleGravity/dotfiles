{
  pkgs,
  lib,
  ...
}: let
  # VM Configuration - can be overridden
  vmConfig = {
    ubuntu = "parallels@uvm.local:/media/psf/Home/";
    nixos = "angel@nixos:/media/psf/Home/";
  };

  # Convert VM config to bash associative array format
  vmConfigBash = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "  [${name}]=\"${value}\"") vmConfig);

  vmScript = pkgs.writeShellApplication {
    name = "vm";
    runtimeInputs = with pkgs; [
      openssh
      coreutils
      gnused
      gnugrep
    ];
    text = ''
      # VM Utilities (UTM Edition)
      # This script provides a unified interface for managing and interacting with UTM virtual machines.

      # Usage:
      #   vm <action> [args]
      #
      # Actions:
      #   ls                     List all VMs
      #   start <vm_name>        Start a VM
      #   stop <vm_name>         Stop a VM
      #   suspend <vm_name>      Suspend a VM
      #   resume <vm_name>       Resume a suspended VM
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
      ${vmConfigBash}
      )

      # Helper function to get the remote path for a VM
      # Args:
      #   $1: VM name
      function _vm_get_remote_path() {
        local vm_name="$1"
        local current_local_path
        current_local_path="$(pwd)"
        local vm_info="''${VM_CONFIG[$vm_name]}"
        local remote_base_path="''${vm_info#*:}"

        if [[ $current_local_path == "$HOME" ]]; then
          echo "''${remote_base_path%/}"
        elif [[ $current_local_path == "/Users/"* ]]; then
          echo "''${remote_base_path}''${current_local_path#/Users/*/}"
        else
          echo "''${remote_base_path}''${current_local_path#"$HOME"}"
        fi
      }

      # Helper function to run a command on a remote VM
      # Args:
      #   $1: VM name
      #   $@: Command to run
      function _vm_run_command() {
        local vm_name="$1"
        shift
        local vm_info="''${VM_CONFIG[$vm_name]}"
        local remote_user="''${vm_info%%@*}"
        local remote_host="''${vm_info#*@}"
        remote_host="''${remote_host%%:*}"

        ssh -t "$remote_user@$remote_host" "$@"
      }

      action="''${1:-}"
      vm_name="''${2:-}"
      shift 2 || true

      case "$action" in
        ls)
          utmctl list
          ;;
        start)
          [[ -z "$vm_name" ]] && { echo "Usage: vm start <vm_name>"; exit 1; }
          utmctl start "$vm_name"
          ;;
        stop)
          [[ -z "$vm_name" ]] && { echo "Usage: vm stop <vm_name>"; exit 1; }
          utmctl stop "$vm_name"
          ;;
        suspend)
          [[ -z "$vm_name" ]] && { echo "Usage: vm suspend <vm_name>"; exit 1; }
          utmctl suspend "$vm_name"
          ;;
        resume)
          [[ -z "$vm_name" ]] && { echo "Usage: vm resume <vm_name>"; exit 1; }
          utmctl start "$vm_name"
          ;;
        restart)
          [[ -z "$vm_name" ]] && { echo "Usage: vm restart <vm_name>"; exit 1; }
          utmctl stop "$vm_name"
          utmctl start "$vm_name"
          ;;
        shell)
          [[ -z "$vm_name" ]] && { echo "Usage: vm shell <vm_name>"; exit 1; }
          remote_path=$(_vm_get_remote_path "$vm_name")
          _vm_run_command "$vm_name" "cd \"$remote_path\" && exec \$SHELL -l"
          ;;
        code|cursor)
          [[ -z "$vm_name" ]] && { echo "Usage: vm $action <vm_name> [-d]"; exit 1; }
          remote_path=$(_vm_get_remote_path "$vm_name")
          vm_info="''${VM_CONFIG[$vm_name]}"
          remote_user="''${vm_info%%@*}"
          remote_host="''${vm_info#*@}"
          remote_host="''${remote_host%%:*}"
          dotfiles_path="/home/$remote_user/.dotfiles"
          target_path="$remote_path"
          [[ "''${1:-}" == "-d" ]] && target_path="$dotfiles_path"
          $action --folder-uri "vscode-remote://ssh-remote+$remote_user@$remote_host\"$target_path\"" --new-window
          ;;
        run)
          [[ -z "$vm_name" ]] && { echo "Usage: vm run <vm_name> <command>"; exit 1; }
          [[ -z "''${1:-}" ]] && { echo "Please specify a command to run"; exit 1; }
          _vm_run_command "$vm_name" "$@"
          ;;
        *)
          echo "Usage: vm <action> [args]"
          echo "Actions: ls, start, stop, suspend, resume, restart, shell, code, cursor, run"
          exit 1
          ;;
      esac
    '';
  };

  completion = pkgs.writeTextFile {
    name = "_vm";
    text = ''
      #compdef vm

      # VM Configuration for completion
      typeset -A VM_CONFIG
      VM_CONFIG=(
      ${vmConfigBash}
      )

      # Function to get VM names from utmctl list
      function _vm_get_utmctl_names() {
        local vm_names
        vm_names=(''${(f)"$(utmctl list 2>/dev/null | tail -n +2 | awk '{print $1}')"})
        _describe -t vm_names 'vm names' vm_names
      }

      # Function to get VM names from VM_CONFIG (for SSH-based commands)
      function _vm_get_config_names() {
        local vm_names
        vm_names=(''${(k)VM_CONFIG})
        _describe -t vm_names 'vm names' vm_names
      }

      # Completion function for vm command
      function _vm() {
        local -a actions
        actions=(
          'ls:List all VMs'
          'start:Start a VM'
          'stop:Stop a VM'
          'suspend:Suspend a VM'
          'resume:Resume a suspended VM'
          'restart:Restart a VM'
          'shell:Open a shell in a VM'
          'code:Open VS Code for a VM'
          'cursor:Open Cursor for a VM'
          'run:Run a command in a VM'
        )

        _arguments \
          '1:action:->actions' \
          '*::arg:->args'

        case $state in
          actions)
            _describe -t actions 'vm actions' actions
            ;;
          args)
            case $words[1] in
              start|stop|suspend|resume|restart)
                _vm_get_utmctl_names
                ;;
              shell|run|code|cursor)
                _vm_get_config_names
                ;;
            esac

            case $words[1] in
              code|cursor)
                if (( CURRENT == 3 )); then
                  _arguments '*:flag:(-d)'
                fi
                ;;
              run)
                if (( CURRENT > 2 )); then
                  _normal
                fi
                ;;
            esac
            ;;
        esac
      }
    '';
    destination = "/share/zsh/site-functions/_vm";
  };
in
  pkgs.symlinkJoin {
    name = "vm";
    paths = [vmScript completion];
    meta = {
      description = "VM management utility for UTM virtual machines";
      platforms = lib.platforms.darwin;
      mainProgram = "vm";
    };
  }
