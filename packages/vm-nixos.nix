{
  lib,
  pkgs,
  runner,
  ...
}:
let
  run = pkgs.writeShellApplication {
    name = "vm-nixos";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      host_pwd="$(pwd -P)"
      case "$host_pwd" in
        "$HOME"|"$HOME"/*)
          vm_pwd="/host/home''${host_pwd#"$HOME"}"
          ;;
        /Users/angel|/Users/angel/*)
          vm_pwd="/host/home''${host_pwd#/Users/angel}"
          ;;
        *)
          vm_pwd="/host/home"
          ;;
      esac

      mkdir -p "$HOME/.cache/vm-nixos"
      printf '%s\n' "$vm_pwd" > "$HOME/.cache/vm-nixos/pwd"

      exec ${runner}/bin/microvm-run "$@"
    '';
  };

  shutdown = pkgs.writeShellApplication {
    name = "vm-nixos-shutdown";
    text = ''
      exec ${runner}/bin/microvm-shutdown "$@"
    '';
  };

  ssh = pkgs.writeShellApplication {
    name = "vm-nixos-ssh";
    runtimeInputs = [pkgs.openssh];
    text = ''
      exec ssh \
        -A \
        -p "''${VM_NIXOS_SSH_PORT:-2222}" \
        -o UserKnownHostsFile=/dev/null \
        -o StrictHostKeyChecking=no \
        root@127.0.0.1 \
        "$@"
    '';
  };
in
  pkgs.symlinkJoin {
    name = "vm-nixos";
    paths = [
      run
      shutdown
      ssh
    ];
    meta = {
      description = "Launcher for the local NixOS MicroVM";
      mainProgram = "vm-nixos";
      platforms = lib.platforms.darwin;
    };
  }
