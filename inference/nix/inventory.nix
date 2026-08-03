{lib}: value: let
  unknownFields = allowed: input: lib.subtractLists allowed (builtins.attrNames input);
  fieldsAreValid = allowed: input: unknownFields allowed input == [];
  validName = name:
    builtins.isString name
    && builtins.match "[a-z0-9]([a-z0-9-]*[a-z0-9])?" name != null;
  isAbsolute = input: builtins.isString input && lib.hasPrefix "/" input;
  nodeNames = builtins.sort builtins.lessThan (builtins.attrNames value.nodes);

  normalizeNode = name: node:
    assert lib.assertMsg (validName name) "inventory node names must be kebab-case";
    assert lib.assertMsg (builtins.isAttrs node) "inventory nodes must be attribute sets";
    assert lib.assertMsg (fieldsAreValid ["platform" "managementAddress" "fabric"] node) "inventory node '${name}' contains unknown fields";
    assert lib.assertMsg (builtins.elem (node.platform or null) ["linux/amd64" "linux/arm64"]) "inventory node '${name}' has an unsupported platform";
    assert lib.assertMsg (builtins.isString (node.managementAddress or null) && node.managementAddress != "") "inventory node '${name}' needs a management address";
    assert lib.assertMsg (builtins.isAttrs (node.fabric or {})) "inventory node '${name}'.fabric must be an attribute set";
    assert lib.assertMsg (fieldsAreValid ["fabric0" "fabric1"] (node.fabric or {})) "inventory node '${name}'.fabric contains unknown fields";
    assert lib.assertMsg (builtins.all (address: builtins.isString address && address != "") (builtins.attrValues (node.fabric or {}))) "inventory fabric addresses must be non-empty strings"; {
      inherit name;
      inherit (node) platform managementAddress;
      fabric = node.fabric or {};
    };
in
  assert lib.assertMsg (builtins.isAttrs value) "mkInventory expects an attribute set";
  assert lib.assertMsg (fieldsAreValid ["localNode" "controlNode" "modelStore" "registry" "nodes"] value) "inventory contains unknown fields";
  assert lib.assertMsg (builtins.isAttrs (value.nodes or null) && value.nodes != {}) "inventory.nodes must be non-empty";
  assert lib.assertMsg (builtins.elem (value.localNode or null) nodeNames) "inventory.localNode must be declared";
  assert lib.assertMsg (builtins.elem (value.controlNode or null) nodeNames) "inventory.controlNode must be declared";
  assert lib.assertMsg (builtins.isAttrs (value.modelStore or null)) "inventory.modelStore must be an attribute set";
  assert lib.assertMsg (fieldsAreValid ["archiveRoot" "localRoot"] value.modelStore) "inventory.modelStore contains unknown fields";
  assert lib.assertMsg (isAbsolute (value.modelStore.archiveRoot or null)) "inventory.modelStore.archiveRoot must be absolute";
  assert lib.assertMsg (isAbsolute (value.modelStore.localRoot or null)) "inventory.modelStore.localRoot must be absolute";
  assert lib.assertMsg (builtins.isAttrs (value.registry or null)) "inventory.registry must be an attribute set";
  assert lib.assertMsg (fieldsAreValid ["endpoint"] value.registry) "inventory.registry contains unknown fields";
  assert lib.assertMsg (builtins.isString (value.registry.endpoint or null) && value.registry.endpoint != "") "inventory.registry.endpoint must be non-empty"; {
    schemaVersion = 1;
    protocolVersion = 1;
    inherit (value) localNode controlNode modelStore registry;
    nodes = map (name: normalizeNode name value.nodes.${name}) nodeNames;
  }
