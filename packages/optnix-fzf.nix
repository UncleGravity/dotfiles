{
  pkgs,
  optnix,
  ...
}: let
  inherit (optnix) scopeList;
in
  pkgs.writeShellApplication {
    name = "optnix-fzf";
    runtimeInputs = [
      pkgs.fzf
      optnix
    ];
    text = ''
      if ! selected=$(
        fzf \
          --delimiter=$'\t' \
          --with-nth=1,2 \
          --prompt="Select scope: " \
          --height=40% \
          --border \
          < "${scopeList}"
      ); then
        exit 0
      fi

      scope_name="''${selected%%$'\t'*}"

      printf 'Running optnix with scope: %s\n' "$scope_name"
      exec optnix --scope "$scope_name" "$@"
    '';
  }
