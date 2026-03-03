{inputs}: final: prev: {
  klayout = prev.klayout.overrideAttrs (old: {
    postBuild = (old.postBuild or "") + prev.lib.optionalString prev.stdenv.hostPlatform.isDarwin ''
      mkdir -p $out/bin
      ln -s $out/Applications/klayout.app/Contents/MacOS/klayout $out/bin/klayout
    '';
  });
}
