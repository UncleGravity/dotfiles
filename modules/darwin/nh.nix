{...}: {
  # ---------------------------------------------------------------------------
  # Garbage collect EVERYTHING older than 30 days
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      interval = {
        Weekday = 0;
        Hour = 0;
      }; # Every Sunday at midnight
      extraArgs = "--keep 5 --keep-since 30d"; # Remove older than 30d, keep at least 5
    };
  };
}
