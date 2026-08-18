{
  config,
  lib,
  options,
  ...
}: let
  clanHostKey = {
    path = config.clan.core.vars.generators.openssh.files."ssh.id_ed25519".path;
    type = "ed25519";
  };
in {
  assertions = lib.optionals (options ? sops) [
    {
      assertion = config.sops.age.keyFile == "/var/lib/sops-nix/key.txt";
      message = "Clan-managed NixOS hosts must use the Clan machine Age identity.";
    }
    {
      assertion = config.services.openssh.hostKeys == [clanHostKey];
      message = "OpenSSH must use exactly the Clan-managed Ed25519 host key.";
    }
  ];

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
