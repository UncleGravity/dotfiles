{inputs}:
#
final: prev: {
  # Personal packages (scripts + wrapped) grouped under `my.*`
  my = prev.lib.recurseIntoAttrs {
    wrappers = inputs.self.packages.${prev.system}.wrappers;
    scripts = inputs.self.packages.${prev.system}.scripts;
  };
}
