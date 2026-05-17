{ ... }:
let
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
  };
}
