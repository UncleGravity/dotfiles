{lib, ...}: {
  services.openssh = {
    enable = true;
    hostKeys = lib.mkDefault [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      PermitRootLogin = "no"; # No root login
      PasswordAuthentication = false; # No password login
      KbdInteractiveAuthentication = false; # No PAM challenge-response either
    };
  };
}
