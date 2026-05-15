{...}: {
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
