{ config, lib, ... }:
let
  # Shorthand to access custom configuration options defined in
  # `nix/modules/common/config.nix`.
  cfg = config.my.config;
in
# Only enable `nh` (nix-helper) housekeeping when we're _not_ inside a VM.
lib.mkIf (!cfg.isVM) {
  # ---------------------------------------------------------------------------
  # Automatic garbage collection & cleanup with `nh`
  programs.nh = {
    enable = true;

    clean = {
      enable = true;
      dates = "weekly";
      # Keep at least 5 generations, and anything younger than 30 days.
      extraArgs = "--keep 5 --keep-since 30d";
    };
  };
}