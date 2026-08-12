{
  lib,
  pkgs,
  vms ? {}, # attrset: { <name> = { runner = <derivation>; }; ... }
  username ? "angel",
  ...
}: let
  vmNames = builtins.attrNames vms;

  # bash assoc array literal: [name]="runner-store-path"
  vmRunnersBash = lib.concatStringsSep "\n" (lib.mapAttrsToList (
      name: vm: ''  [${name}]="${vm.runner}"''
    )
    vms);

  # zsh completion list: name name name
  vmNamesZsh = lib.concatStringsSep " " vmNames;

  vmScript = pkgs.writeShellApplication {
    name = "vm";
    runtimeInputs = with pkgs; [
      coreutils
      openssh
      gawk
      curl
      util-linux # setsid (for `start -d`)
    ];
    text = ''
      # VM dispatcher for microvm.nix-based VMs running under vfkit on darwin.
      #
      # Usage:
      #   vm ls                  List all VMs with status
      #   vm start <name> [-d]   Start a VM (foreground; -d to detach)
      #   vm stop <name>         Stop a VM
      #   vm ssh <name> [args]   SSH into a running VM

      declare -A VM_RUNNERS=(
      ${vmRunnersBash}
      )

      USERNAME="${username}"
      CACHE_BASE="$HOME/.cache/vm"

      usage() {
        cat <<EOF
      Usage: vm <command> [args]

      Commands:
        ls                     List all VMs with status
        start <name> [-d]      Start a VM (-d to detach)
        stop <name> [-f]       Stop a VM (-f / --force = HardStop)
        ssh <name> [..]        SSH into a running VM

      Known VMs: ${vmNamesZsh}
      EOF
        exit 1
      }

      vm_known() {
        [[ -n "''${VM_RUNNERS[$1]+x}" ]]
      }

      vm_socket() {
        printf '/tmp/vm-%s.sock' "$1"
      }

      # `vm_alive` distinguishes a live vfkit from a stale socket file (left
      # behind by an unclean exit). The socket-file check alone lies: it stays
      # on disk and `[[ -S ]]` returns true with nobody listening.
      vm_alive() {
        local sock
        sock="$(vm_socket "$1")"
        [[ -S "$sock" ]] || return 1
        curl -fsS --max-time 1 --unix-socket "$sock" \
          http://localhost/vm/state >/dev/null 2>&1
      }

      # Remove a stale socket file (vfkit dead, file lingering). Safe no-op
      # if vfkit is actually alive — we guard with vm_alive at every call site.
      # (Uses `if` rather than `&&`-chain so a missing socket doesn't return
      # non-zero from the function and trip `set -e` at the call site.)
      reap_stale_socket() {
        local sock
        sock="$(vm_socket "$1")"
        if [[ -S "$sock" ]]; then
          rm -f "$sock"
        fi
      }

      # Map current host cwd → guest path under /host/home so the VM's login
      # shell can `cd` into the matching directory (see base.nix
      # programs.bash.loginShellInit). Writes to <cache>/<name>/pwd.
      sync_pwd() {
        local name="$1"
        local host_pwd
        host_pwd="$(pwd -P)"
        local vm_pwd
        case "$host_pwd" in
          "$HOME"|"$HOME"/*)
            vm_pwd="/host/home''${host_pwd#"$HOME"}"
            ;;
          "/Users/$USERNAME"|"/Users/$USERNAME"/*)
            vm_pwd="/host/home''${host_pwd#"/Users/$USERNAME"}"
            ;;
          *)
            vm_pwd="/host/home"
            ;;
        esac
        mkdir -p "$CACHE_BASE/$name"
        printf '%s\n' "$vm_pwd" > "$CACHE_BASE/$name/pwd"
      }

      # Resolve guest IP via macOS' dhcpd lease file. vfkit's "nat" mode is
      # backed by Apple's vmnet (shared), so the host sits on the same private
      # subnet as the guest and bootpd records its lease here.
      #
      # We match on the DHCP "name" field (= networking.hostName) rather than
      # hw_address: systemd-networkd sends a DUID-based client identifier
      # (DHCP option 61), so bootpd records that instead of the Ethernet MAC.
      # Pick the entry with the freshest "lease=" timestamp to avoid stale
      # leases from previous boots.
      resolve_ip() {
        local name="$1"
        local timeout="''${2:-30}"
        local leases=/var/db/dhcpd_leases
        local ip=""
        local deadline=$(( $(date +%s) + timeout ))
        while [[ "$(date +%s)" -le "$deadline" ]]; do
          if [[ -r "$leases" ]]; then
            ip=$(awk -v name="$name" '
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
          [[ -n "$ip" ]] && break
          [[ "$timeout" -eq 0 ]] && break
          sleep 1
        done
        if [[ -z "$ip" ]]; then
          return 1
        fi
        printf '%s\n' "$ip"
      }

      cmd_ls() {
        if [[ $# -gt 0 ]]; then
          echo "vm ls: unexpected argument '$1'" >&2
          exit 1
        fi
        printf '%-12s %-10s %s\n' "NAME" "STATUS" "IP"
        for name in "''${!VM_RUNNERS[@]}"; do
          local status="stopped"
          local ip="-"
          if vm_alive "$name"; then
            status="running"
            ip="$(resolve_ip "$name" 0 || true)"
            [[ -z "$ip" ]] && ip="-"
          else
            # Socket file present but no vfkit answering: reap so subsequent
            # `start` doesn't think the VM is up.
            reap_stale_socket "$name"
          fi
          printf '%-12s %-10s %s\n' "$name" "$status" "$ip"
        done
      }

      cmd_start() {
        local name=""
        local detach=0
        while [[ $# -gt 0 ]]; do
          case "$1" in
            -d|--detach)
              detach=1
              shift
              ;;
            --)
              shift
              break
              ;;
            -*)
              echo "vm start: unknown flag '$1'" >&2
              exit 1
              ;;
            *)
              if [[ -z "$name" ]]; then
                name="$1"
              else
                echo "vm start: unexpected extra argument '$1'" >&2
                exit 1
              fi
              shift
              ;;
          esac
        done
        if [[ $# -gt 0 ]]; then
          echo "vm start: unexpected extra argument '$1'" >&2
          exit 1
        fi
        if [[ -z "$name" ]]; then
          echo "vm start: missing VM name" >&2
          exit 1
        fi

        vm_known "$name" || { echo "vm: unknown VM '$name' (known: ${vmNamesZsh})" >&2; exit 1; }
        if vm_alive "$name"; then
          echo "vm: '$name' already running" >&2
          exit 0
        fi
        # Stale socket from a previous crash would otherwise make vfkit fail
        # on bind; reap it now that we know nothing's listening.
        reap_stale_socket "$name"

        mkdir -p "$CACHE_BASE/$name"
        sync_pwd "$name"
        local runner="''${VM_RUNNERS[$name]}"

        if (( detach )); then
          local log="$CACHE_BASE/$name/log"
          # vfkit's stdio console requires a TTY on stdin; bare nohup/setsid
          # drops the controlling terminal and vfkit fails with
          # "Adding stdio console: operation not supported by device".
          # Wrap the runner in macOS `script` to allocate a pty (typescript
          # is discarded; we only keep our own log redirect).
          setsid -f /usr/bin/script -q /dev/null "$runner/bin/microvm-run" \
            >"$log" 2>&1 < /dev/null
          echo "vm: started '$name' (log: $log)"
        else
          exec "$runner/bin/microvm-run"
        fi
      }

      cmd_stop() {
        local name=""
        local force=0
        while [[ $# -gt 0 ]]; do
          case "$1" in
            -f|--force)
              force=1
              shift
              ;;
            --)
              shift
              break
              ;;
            -*)
              echo "vm stop: unknown flag '$1'" >&2
              exit 1
              ;;
            *)
              if [[ -z "$name" ]]; then
                name="$1"
              else
                echo "vm stop: unexpected extra argument '$1'" >&2
                exit 1
              fi
              shift
              ;;
          esac
        done
        if [[ $# -gt 0 ]]; then
          echo "vm stop: unexpected extra argument '$1'" >&2
          exit 1
        fi
        if [[ -z "$name" ]]; then
          echo "vm stop: missing VM name" >&2
          exit 1
        fi

        vm_known "$name" || { echo "vm: unknown VM '$name' (known: ${vmNamesZsh})" >&2; exit 1; }
        local sock
        sock="$(vm_socket "$name")"
        if ! vm_alive "$name"; then
          if [[ -S "$sock" ]]; then
            reap_stale_socket "$name"
            echo "vm: '$name' was stale (cleaned socket $sock)" >&2
          else
            echo "vm: '$name' not running (no socket at $sock)" >&2
          fi
          exit 0
        fi
        # Upstream microvm-shutdown for vfkit sends raw JSON over a Unix socket
        # that expects HTTP, so it silently does nothing. vfkit's actual REST
        # surface is POST /vm/state with {"state":"Stop"}.
        # TODO: Upstream fix?
        #
        # "Stop" is graceful — guest must cooperate (e.g. systemd shutdown).
        # A guest stuck mid-boot or unresponsive will ignore it. --force
        # uses "HardStop" which terminates vfkit immediately.
        local target_state="Stop"
        (( force )) && target_state="HardStop"
        curl -fsS --unix-socket "$sock" \
          -X POST -H 'Content-Type: application/json' \
          -d "{\"state\":\"$target_state\"}" \
          http://localhost/vm/state
      }

      cmd_ssh() {
        if [[ $# -lt 1 ]]; then
          echo "vm ssh: missing VM name" >&2
          exit 1
        fi
        local name="$1"
        shift
        vm_known "$name" || { echo "vm: unknown VM '$name' (known: ${vmNamesZsh})" >&2; exit 1; }

        if ! vm_alive "$name"; then
          reap_stale_socket "$name"
          echo "vm: '$name' is not running (start it with: vm start $name -d)" >&2
          exit 1
        fi

        sync_pwd "$name"

        local ip
        if ! ip="$(resolve_ip "$name" 30)"; then
          echo "vm: timed out waiting for DHCP lease (name=$name)" >&2
          exit 1
        fi

        exec ssh \
          -A \
          -o UserKnownHostsFile=/dev/null \
          -o StrictHostKeyChecking=no \
          -o LogLevel=ERROR \
          "$USERNAME@$ip" \
          "$@"
      }

      action="''${1:-}"
      shift || true

      case "$action" in
        ls)    cmd_ls "$@" ;;
        start) cmd_start "$@" ;;
        stop)  cmd_stop "$@" ;;
        ssh)   cmd_ssh "$@" ;;
        ""|-h|--help|help)
          usage
          ;;
        *)
          echo "vm: unknown command '$action'" >&2
          usage
          ;;
      esac
    '';
  };

  completion = pkgs.writeTextFile {
    name = "_vm";
    text = ''
      #compdef vm

      # Mirrors the _git/_docker pattern: top-level _arguments matches the
      # subcommand, then `*::arg:->args` re-enters with $words/$CURRENT
      # adjusted so each per-subcommand _arguments call sees positional 1 as
      # the FIRST arg AFTER the subcommand. This gives us flag-anywhere
      # semantics (`-d dev` and `dev -d` both work) and exclusion groups
      # (no double-suggesting -d/--detach) without manual CURRENT math.
      _vm() {
        local curcontext="$curcontext" state line
        local -a actions
        actions=(
          'ls:List all VMs with status'
          'start:Start a VM'
          'stop:Stop a VM'
          'ssh:SSH into a running VM'
        )

        _arguments -C \
          '1: :->command' \
          '*::arg:->args'

        case $state in
          command)
            _describe -t actions 'vm actions' actions
            ;;
          args)
            case $line[1] in
              start)
                _arguments \
                  '(-d --detach)'{-d,--detach}'[detach into background]' \
                  '1:vm name:(${vmNamesZsh})'
                ;;
              stop)
                _arguments \
                  '(-f --force)'{-f,--force}'[force (HardStop)]' \
                  '1:vm name:(${vmNamesZsh})'
                ;;
              ssh)
                _arguments \
                  '1:vm name:(${vmNamesZsh})' \
                  '*::ssh args: '
                ;;
              ls)
                ;;
            esac
            ;;
        esac
      }

      _vm "$@"
    '';
    destination = "/share/zsh/site-functions/_vm";
  };
in
  pkgs.symlinkJoin {
    name = "vm";
    paths = [vmScript completion];
    meta = {
      description = "Dispatcher for local microvm.nix VMs (start/stop/ls/ssh)";
      platforms = lib.platforms.darwin;
      mainProgram = "vm";
    };
  }
