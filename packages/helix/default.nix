{
  helix,
  symlinkJoin,
  makeWrapper,
}:
# Wrapped `hx` that always uses our custom config.
symlinkJoin {
  name = "helix-${helix.version}";
  paths = [helix];
  nativeBuildInputs = [makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/hx \
      --add-flags "--config ${./config.toml}"
  '';
  meta =
    helix.meta
    // {
      mainProgram = "hx";
    };
}
