{
  imports = [
    ../common

    # ── Baseline (always applied) ─────────────────────────────
    ./boot.nix
    ./locale.nix
    ./nh.nix
    ./nix.nix
    ./pkgs.nix
    ./print.nix
    ./shells.nix
    ./ssh.nix
    ./users.nix

    # ── Role profiles (opt in: my.profiles.<role>.enable) ─────
    ./profiles/server.nix
    ./profiles/graphical.nix
    ./profiles/workstation.nix

    # ── Features (opt in: my.<feature>.enable) ────────────────
    ./features/display-manager.nix
    ./features/docker.nix
    ./features/escape-hatch.nix
    ./features/guacamole.nix
    ./features/hackrf.nix
    ./features/immich.nix
    ./features/tailscale.nix
  ];

  # ---------------------------------------------------------------------------
  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # ---------------------------------------------------------------------------
  # services.flatpak.enable = true; # enable flatpak (required by host-spawn / distrobox-host-exec)
}
