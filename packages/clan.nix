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

    # TODO: TEMPORARY CLAN MIGRATION HACK.
    # Remove this shortcut and the local keys.txt copy when the transition is complete.
    if [[ -n "''${XDG_CONFIG_HOME:-}" ]]; then
      local_identity="$XDG_CONFIG_HOME/sops/age/keys.txt"
    elif [[ "''${OSTYPE:-}" == darwin* ]]; then
      local_identity="$HOME/Library/Application Support/sops/age/keys.txt"
    else
      local_identity="$HOME/.config/sops/age/keys.txt"
    fi
    if [[ -f "$local_identity" && -r "$local_identity" ]]; then
      unset SOPS_AGE_KEY_CMD
      export SOPS_AGE_KEY_FILE="$local_identity"
      exec ${lib.getExe clanCli} "$@"
    fi

    unset SOPS_AGE_KEY_CMD SOPS_AGE_KEY_FILE
    export SOPS_AGE_KEY="op://Personal/master-ssh-key/private-key-age"

    exec ${lib.getExe pkgs._1password-cli} run -- ${lib.getExe clanCli} "$@"
  '';

  meta.description = "Clan CLI with the local or 1Password operator Age identity";
}
