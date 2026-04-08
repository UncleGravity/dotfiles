{
  config,
  lib,
  pkgs,
  username,
  ...
}: {
  sops.secrets."ntfy/topic" = {
    owner = username;
    mode = "0400";
  }; # For NTFY notifications

  environment = {
    # --------------------------------------------
    # BUGFIX: ntfy-sh does not work on Darwin
    systemPackages = [
      (pkgs.ntfy-sh.overrideAttrs (oldAttrs: {
        buildInputs = (oldAttrs.buildInputs or []) ++ [pkgs.git];
        postPatch =
          (oldAttrs.postPatch or "")
          + lib.optionalString pkgs.stdenv.isDarwin ''
            substituteInPlace cmd/serve_unix.go \
              --replace-fail '//go:build linux || dragonfly || freebsd || netbsd || openbsd' '//go:build darwin || linux || dragonfly || freebsd || netbsd || openbsd'
          '';
      }))
    ];
    # --------------------------------------------
    variables.NTFY_TOPIC = "$(cat ${config.sops.secrets."ntfy/topic".path})";
    shellAliases."ntfy" = "ntfy publish";
  };
}
