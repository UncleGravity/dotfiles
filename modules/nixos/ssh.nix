{...}: {
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no"; # No root login
      PasswordAuthentication = false; # No password login
    };
  };
}
