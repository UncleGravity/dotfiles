{inputs}:
#
final: prev: {
  # Personal packages (scripts + wrapped) grouped under `my.*`
  my = prev.lib.recurseIntoAttrs {
    scripts = inputs.self.packages.${prev.stdenv.hostPlatform.system}.scripts;
    packages = inputs.self.packages.${prev.stdenv.hostPlatform.system}.packages;
  };
}
