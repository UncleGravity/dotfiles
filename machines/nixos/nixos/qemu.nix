# vm.nix
{
  inputs,
  lib,
  pkgs,
  ...
}: {
  sops.age.sshKeyPaths = [
    # "/etc/ssh/ssh_host_ed25519_key"
    "/host/ssh/ssh_host_ed25519_key" # your extra key if you still want it
  ];

  # QEMU STUFF
  virtualisation.vmVariant.virtualisation = {
    graphics = false; # Make VM output to the terminal instead of a separate window
    memorySize = 4096;
    host.pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
    sharedDirectories = {
      # -- Mount host directories into VM
      home = {
        source = "/Users/angel";
        target = "/host/home";
      };
      sops = {
        source = "/etc/ssh";
        target = "/host/ssh";
      };
    }; # --
  };

  # Set terminal type for color support
  environment.variables = {
    TERM = "screen-256color";
    COLORTERM = "truecolor";
  };

  # Create direct symlinks to working terminfo entries
  # environment.etc = {
  #   "terminfo/s/screen-256color".source = "${pkgs.ncurses}/share/terminfo/73/screen-256color";
  #   "terminfo/x/xterm-256color".source = "${pkgs.ncurses}/share/terminfo/78/xterm-256color";
  # };
  # Fix home directory ownership when VM is run with sudo
  # boot.postBootCommands = ''
  #   if [ -d /home/angel ] && [ "$(stat -c %U /home/angel)" = "root" ]; then
  #     chown -R angel:users /home/angel
  #   fi
  # '';
}
# nix run github:nix-community/nixos-generators -- --flake .#nixos --format raw-efi

