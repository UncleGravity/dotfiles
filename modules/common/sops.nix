{
  config,
  pkgs,
  username,
  lib,
  ...
}: let
  secretsDir = ../../secrets;
in {
  #############################################################
  #  SOPS
  #############################################################

  sops = {
    age.sshKeyPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];
    # age.keyFile = "${config.users.users.${username}.home}/.config/sops/age/keys.txt";
    defaultSopsFile = "${secretsDir}/secrets.yaml";
    validateSopsFiles = true;
    # validateSopsFiles = builtins.pathExists "/etc/ssh/ssh_host_ed25519_key"; # Only validate when SSH key exists (not in CI)

    secrets = lib.mkMerge [
      # Work secrets, only on macOS machines
      (lib.mkIf pkgs.stdenv.isDarwin {
        "work.zsh" = {
          path = "${config.users.users.${username}.home}/.config/zsh/secrets/work.zsh";
          owner = username;
          mode = "0600";
        };
      })
      # Home secrets, on all machines / servers
      {
        "home.zsh" = {
          path = "${config.users.users.${username}.home}/.config/zsh/secrets/home.zsh";
          owner = username;
          mode = "0600";
        };
      }
    ];
  };
}
