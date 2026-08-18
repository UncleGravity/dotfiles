{lib, ...}: {
  sops.age.sshKeyPaths = lib.mkForce [];
  sops.gnupg.sshKeyPaths = lib.mkForce [];
}
