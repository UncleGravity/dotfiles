{lib, ...}: {
  imports = [
    ./server.nix
    ./workstation.nix
  ];

  options.my.profile = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum ["server" "workstation"]);
    default = null;
    description = "Optional NixOS configuration preset";
  };
}
