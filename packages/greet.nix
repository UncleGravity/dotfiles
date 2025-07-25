{pkgs, ...}:
pkgs.writeShellApplication {
  name = "greet";
  runtimeInputs = [pkgs.coreutils];
  text = ''
    #!${pkgs.runtimeShell}
    echo "Hello from Nix shell script!"
  '';
}
