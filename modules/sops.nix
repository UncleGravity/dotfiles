{
  config,
  pkgs,
  username,
  lib,
  ...
}: let
  secretsDir = ../secrets;
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
    environment = {
      # SOPS_AGE_KEY_CMD = ''su - ${username} -c "op item get \"master-ssh-key\" --field \"private-key-age\" --reveal"'';
      # SOPS_AGE_KEY_CMD = "${secretsDir}/keys.sh";
      # SOPS_AGE_SSH_PRIVATE_KEY_FILE = "${config.users.users.${username}.home}/.ssh/id_ed25519";
    };

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
