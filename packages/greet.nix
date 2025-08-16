{
  pkgs,
  lib,
  ...
}:
pkgs.writeShellApplication {
  name = "greet";
  runtimeInputs = [pkgs.coreutils];
  text = ''
    echo "Hello from Nix shell script!"
  '';
  meta = {
    platforms = lib.platforms.darwin;
    # platforms = lib.platforms.linux;
  };
}
