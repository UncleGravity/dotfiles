{lib, ...}: {
  # ---------------------------------------------------------------------------
  # Role profiles
  #
  # Flat booleans that each host composes by enabling 1–2 of them. Roles are
  # orthogonal to platform: a Darwin laptop is `workstation + graphical`; a
  # NixOS NAS with GUI for RDP is `server + graphical`; a pure headless box
  # is just `server`.
  #
  # Modules `mkIf config.my.profiles.<role>.enable { ... }` to gate whole
  # blocks of config behind a role. Keep this file as the *only* place these
  # options are declared on the system side.
  #
  # Note: this schema is system-only. Home-manager has its own decisions and
  # declares its own options where it needs them (see modules/home/).
  # ---------------------------------------------------------------------------
  options.my.profiles = {
    workstation.enable = lib.mkEnableOption "interactive daily-driver (dev tooling, NetworkManager, autologin)";
    server.enable = lib.mkEnableOption "always-on host (no sleep, hardened sshd, monitoring)";
    graphical.enable = lib.mkEnableOption "display + audio (pipewire, printing, fonts)";
  };
}
