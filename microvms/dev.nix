{pkgs, ...}: {
  imports = [./base.nix];

  microvm.vcpu = 4;
  microvm.mem = 4096;

  environment.systemPackages = with pkgs; [
    git
    neovim
    ripgrep
    fd
    jq
    yazi
    nushell
    cyme
    cowsay
    xilinx-bootgen
    # clang
    # gcc
  ];
}
