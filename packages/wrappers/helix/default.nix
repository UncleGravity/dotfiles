{pkgs, ...}: {
  # Create a wrapped version of `hx` that always uses our custom config
  wrappers.helix = {
    basePackage = pkgs.helix;
    appendFlags = ["--config" ./config.toml];
    pathAdd = [
      # pkgs.nixd
      # etc
    ];
  };
}
