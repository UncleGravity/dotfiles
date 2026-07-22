{
  username,
  ...
}: {
  # SSH keys authorized to log in as `${username}` on every host.
  users.users.${username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICzI2b0Spyh5wIm6mLVPKaDonuea0a7sdNFGN2V1HTRq" # Master
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLpjzihuPI+t7xYjznPNLALMCunS2WKw/cqYRMAG1YILTGiLmdYRWck9Ic7muK7SXWj0XP8nWTze1iRhA/iTyxA=" # CRISPR (termius)
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEInOZ8KpWVwbYHVSkTjAeFxtRxNi3lnTkJ4n56g6Acr" # banana (local id_ed25519, prompt-free deploys)
  ];
}
