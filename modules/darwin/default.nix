{
  imports = [
    ../common
    ./_core.nix
    ./apfs-snapshots.nix
    ./homebrew.nix
    ./_nh.nix # TODO: REPLACE when nix-darwin/nix-darwin/pull/942 is merged
  ];
}
