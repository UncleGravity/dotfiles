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
    runtimeInputs = [pkgs.curl];
    text = ''
      # Upstream microvm-shutdown for vfkit sends raw JSON over a Unix socket
      # that expects HTTP, so it silently does nothing. vfkit's actual REST
      # surface is POST /vm/state with {"state":"Stop"}.
      # TODO: Upstream fix?
      sock=/tmp/vm-nixos.sock
      if [ ! -S "$sock" ]; then
        echo "vm-nixos: not running (no socket at $sock)" >&2
        exit 0
      fi
      curl -fsS --unix-socket "$sock" \
        -X POST -H 'Content-Type: application/json' \
        -d '{"state":"Stop"}' \
        http://localhost/vm/state
    '';
  };

  ssh = pkgs.writeShellApplication {
    name = "vm-nixos-ssh";
    runtimeInputs = [pkgs.openssh pkgs.gawk pkgs.coreutils];
    text = ''
      # Sync host cwd → guest path so the login shell lands in the right
      # place (consumed by programs.bash.loginShellInit in vm-nixos.nix).
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

      # Resolve guest IP via macOS' dhcpd lease file. vfkit's "nat" mode is
      # backed by Apple's vmnet (shared), so the host sits on the same private
      # subnet as the guest and bootpd records its lease here.
      #
      # We match on the DHCP "name" field (= networking.hostName in the guest)
      # rather than hw_address: systemd-networkd sends a DUID-based client
      # identifier (DHCP option 61), so bootpd records that instead of the
      # Ethernet MAC. Pick the entry with the freshest "lease=" timestamp to
      # avoid stale leases from previous boots.
      target_name="vm-nixos"
      leases=/var/db/dhcpd_leases

      ip=""
      deadline=$(( $(date +%s) + 30 ))
      while [ "$(date +%s)" -lt "$deadline" ]; do
        if [ -r "$leases" ]; then
          ip=$(awk -v name="$target_name" '
            function clean(s) { sub(/^[^=]*=/,"",s); gsub(/[[:space:]]/,"",s); return s }
            /^{/  { ip_v=""; name_v=""; lease_v="" }
            /^[[:space:]]*name=/        { name_v  = clean($0) }
            /^[[:space:]]*ip_address=/  { ip_v    = clean($0) }
            /^[[:space:]]*lease=/       { lease_v = clean($0) }
            /^}/  {
              if (name_v == name && ip_v != "") {
                l = strtonum(lease_v)
                if (l >= best_lease) { best_lease = l; best_ip = ip_v }
              }
            }
            END { if (best_ip != "") print best_ip }
          ' "$leases")
        fi
        [ -n "$ip" ] && break
        sleep 1
      done

      if [ -z "$ip" ]; then
        echo "vm-nixos-ssh: timed out waiting for DHCP lease (name=$target_name)" >&2
        exit 1
      fi

      exec ssh \
        -A \
        -o UserKnownHostsFile=/dev/null \
        -o StrictHostKeyChecking=no \
        -o LogLevel=ERROR \
        "angel@$ip" \
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
