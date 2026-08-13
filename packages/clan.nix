{
  clanCli,
  lib,
  pkgs,
}:
pkgs.writeShellApplication {
  name = "clan";

  text = ''
    set +x

    if [[ -n "''${SOPS_AGE_KEY:-}" || -n "''${SOPS_AGE_KEY_FILE:-}" ]]; then
      unset SOPS_AGE_KEY_CMD
      exec ${lib.getExe clanCli} "$@"
    fi

    unset SOPS_AGE_KEY_CMD SOPS_AGE_KEY_FILE
    export SOPS_AGE_KEY="op://Personal/master-ssh-key/private-key-age"

    exec ${lib.getExe pkgs._1password-cli} run -- ${lib.getExe clanCli} "$@"
  '';

  meta.description = "Clan CLI with the operator Age identity from 1Password";
}
