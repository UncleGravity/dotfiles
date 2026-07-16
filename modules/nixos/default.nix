{
  imports = [
    ../common

    # ── Baseline (always applied) ---------------------------------------
    ./boot.nix
    ./locale.nix
    ./nh.nix
    ./nix.nix
    ./pkgs.nix
    ./print.nix
    ./shells.nix
    ./ssh.nix
    ./users.nix
    # ── Profile defaults (selected by my.profile) -----------------------
    ./profiles

    # ── Features (opt in: my.<feature>.enable) --------------------------
    ./features/audio.nix
    ./features/desktop.nix
    ./features/docker.nix
    ./features/escape-hatch.nix
    ./features/guacamole.nix
    ./features/hackrf.nix
    ./features/immich.nix
    ./features/nvidia-ai.nix
    ./features/power.nix
    ./features/tailscale.nix
  ];

  # ----------------------------------------------------------------------
  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # ----------------------------------------------------------------------
  # services.flatpak.enable = true; # enable flatpak (required by host-spawn / distrobox-host-exec)
}
