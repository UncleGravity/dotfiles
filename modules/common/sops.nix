{lib, ...}: {
  #############################################################
  #  SOPS
  #############################################################

  sops = {
    age.sshKeyPaths = lib.mkForce [];
    gnupg.sshKeyPaths = lib.mkForce [];
    validateSopsFiles = true;
  };
}
