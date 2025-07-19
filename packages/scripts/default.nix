
{ lib, pkgs, stdenvNoCC, system }:

##############################################################################
# 1.  Main “fat” bundle – installs every relevant script + completions
##############################################################################
let
  # Directories that contain scripts for the current platform
  platformDirs =
    [ ./all ]
    ++ lib.optionals pkgs.stdenv.isDarwin [ ./darwin ]
    ++ lib.optionals pkgs.stdenv.isLinux  [ ./linux ];

  bundle = stdenvNoCC.mkDerivation {
    pname   = "scripts";
    version = "1.0.0";
    src     = ./.;

    dontConfigure = true;
    dontBuild     = true;

    installPhase = ''
      mkdir -p "$out/bin" "$out/share/zsh/site-functions"

      # Install scripts
      for dir in ${lib.concatStringsSep " " (map toString platformDirs)}; do
        if [ -d "$dir" ]; then
          for f in "$dir"/*; do
            [ -f "$f" ] && install -Dm755 "$f" "$out/bin/$(basename "$f")"
          done
        fi
      done

      # Install zsh completions
      if [ -d _completions ]; then
        for c in _completions/_*; do
          [ -f "$c" ] && install -Dm644 "$c" \
            "$out/share/zsh/site-functions/$(basename "$c")"
        done
      fi
    '';

    meta = {
      description = "Personal shell scripts and Z-sh completions (full bundle)";
      platforms   = lib.platforms.all;
      mainProgram = "placeholder";  # suppressed by wrappers below
    };
  };

##############################################################################
# 2.  Discover script names present in the bundle
##############################################################################
  scriptsFromDir = dir:
    lib.attrNames (lib.filterAttrs (_: t: t == "regular") (builtins.readDir dir));

  scriptNames =
    lib.unique (
      scriptsFromDir ./all
      ++ lib.optionals pkgs.stdenv.isDarwin (scriptsFromDir ./darwin)
      ++ lib.optionals pkgs.stdenv.isLinux  (scriptsFromDir ./linux)
    );

##############################################################################
# 3.  Produce one lightweight wrapper derivation per script
##############################################################################
  inherit (pkgs) symlinkJoin;

  mkScript = name:
    symlinkJoin {
      name  = "script-${name}";
      paths = [ bundle ];

      postBuild = ''
        mkdir -p "$out/bin"
        ln -sf ${bundle}/bin/${name} "$out/bin/${name}"
      '';

      meta = {
        description = "Standalone wrapper for '${name}' script";
        mainProgram = name;  # enables `nix run .#scripts.${name}`
        platforms   = lib.platforms.all;
      };
    };

  perScriptPkgs = lib.genAttrs scriptNames mkScript;

##############################################################################
# 4.  Expose everything
##############################################################################
in
perScriptPkgs // { default = bundle; }
