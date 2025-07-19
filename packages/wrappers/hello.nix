{pkgs, ...}: {
  # A wrapper-manager module that creates a wrapped variant
  # of the standard `pkgs.hello` package.  The resulting
  # executable will print “Hello, world! I AM WRAPPED”.
  wrappers.hello = {
    basePackage = pkgs.hello;
    prependFlags = ["-g" "I AM WRAPPED"];
  };
}
