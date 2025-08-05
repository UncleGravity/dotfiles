{pkgs, ...}: {
  # A wrapper-manager module that creates a wrapped variant
  # of the standard `pkgs.hello` package.
  wrappers.hello = {
    basePackage = pkgs.hello;
    prependFlags = ["-g" "I AM BATMAN"];
  };
}
