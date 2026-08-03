{lib}: {
  mkCatalog = import ../catalog.nix {inherit lib;};
  mkInventory = import ../inventory.nix {inherit lib;};
  mkInstanceCatalog = import ../instances.nix {inherit lib;};
}
