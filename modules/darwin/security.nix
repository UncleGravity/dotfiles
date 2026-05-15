{lib, ...}: {
  # Enable TouchID for sudo authentication
  security.pam.services.sudo_local = {
    enable = lib.mkDefault true;
    touchIdAuth = lib.mkDefault true;
    reattach = lib.mkDefault true; # TMUX fix https://github.com/LnL7/nix-darwin/pull/787
  };
}
