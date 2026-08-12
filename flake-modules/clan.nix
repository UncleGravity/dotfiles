{inputs, ...}: {
  imports = [inputs.clan-core.flakeModules.default];

  clan = {
    # Avoid autoincluding the current machines/{nixos,darwin} grouping directories.
    directory = "${inputs.self}/flake-modules";
    meta = {
      name = "angelnet";
      domain = "angel.pizza";
    };
  };
}
