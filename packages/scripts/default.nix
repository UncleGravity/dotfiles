{
  lib,
  pkgs,
  stdenvNoCC,
  system,
}:

##############################################################################
# 1. ––––– Build the original “everything” bundle just like before
##############################################################################
let
  bundle = stdenvNoCC.mkDerivation {
    pname   = "scripts";
    version = "1.0.0";
    src     = ./.;

    installPhase = ''
      runHook preInstall
      export system=${system}
      bash ${./install.sh}
      runHook postInstall
    '';

    meta = with lib; {
      description = "Personal shell scripts and completions (full bundle)";
      platforms   = platforms.all;
    };
  };

##############################################################################
# 2. ––––– Figure out which scripts end up in $bundle/bin
##############################################################################
  inherit (pkgs) symlinkJoin;

  # The bundle isn’t built yet, but we know exactly which source files it will
  # install, so we can inspect the source tree instead of $bundle itself.
  #
  # Helper to collect regular files from a directory (non-recursive).
  scriptsFromDir = dir:
    lib.attrNames
      (lib.filterAttrs (_: t: t == "regular") (builtins.readDir dir));

  commonScripts  = scriptsFromDir ./all;
  darwinScripts  = lib.optional pkgs.stdenv.isDarwin (scriptsFromDir ./darwin);
  linuxScripts   = lib.optional pkgs.stdenv.isLinux  (scriptsFromDir ./linux);

  scriptNames =
    lib.unique (commonScripts ++ lib.flatten (darwinScripts ++ linuxScripts));

##############################################################################
# 3. ––––– Produce one wrapper derivation per script
##############################################################################
  mkScript = name:
    symlinkJoin {
      name  = "script-${name}";
      paths = [ bundle ];

      postBuild = ''
        mkdir -p "$out/bin"
        ln -sf ${bundle}/bin/${name} "$out/bin/${name}"
      '';

      meta = with lib; {
        description  = "Standalone wrapper for '${name}' script";
        mainProgram  = name;        # enables `nix run`
        platforms    = platforms.all;
      };
    };

  perScriptPkgs = lib.genAttrs scriptNames mkScript;

##############################################################################
# 4. ––––– Expose everything
##############################################################################
in
perScriptPkgs // {
  # Keep the old “everything” derivation for convenience.
  default = bundle;
}
