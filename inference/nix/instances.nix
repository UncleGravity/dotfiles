{lib}: {
  instances,
  recipes,
  nodes,
  localNode,
}: let
  validName = name:
    builtins.isString name
    && builtins.match "[a-z0-9]([a-z0-9-]*[a-z0-9])?" name != null;
  names = builtins.sort builtins.lessThan (builtins.attrNames instances);
  nodeNames = builtins.attrNames nodes;
  fieldsAreValid = allowed: value: lib.subtractLists allowed (builtins.attrNames value) == [];

  normalize = name: instance: let
    selectedNodes = lib.unique (instance.nodes or [localNode]);
    recipeName = instance.recipe or null;
    recipe = recipes.${recipeName} or null;
  in
    assert lib.assertMsg (validName name) "inference instance names must be kebab-case";
    assert lib.assertMsg (builtins.isAttrs instance) "inference instance '${name}' must be an attribute set";
    assert lib.assertMsg (fieldsAreValid ["recipe" "nodes" "autoStart"] instance) "inference instance '${name}' contains unknown fields";
    assert lib.assertMsg (recipe != null) "inference instance '${name}' references an unknown recipe";
    assert lib.assertMsg (builtins.all (node: builtins.elem node nodeNames) selectedNodes) "inference instance '${name}' references an unknown node";
    assert lib.assertMsg (builtins.elem (builtins.length selectedNodes) recipe.topology.nodeCounts) "inference instance '${name}' uses an unsupported node count";
    assert lib.assertMsg (builtins.all (node: nodes.${node}.platform == recipe.image.platform) selectedNodes) "inference instance '${name}' has a platform mismatch"; {
      inherit name;
      recipe = recipeName;
      nodes = selectedNodes;
      autoStart = instance.autoStart or false;
    };
  normalized = map (name: normalize name instances.${name}) names;
in
  builtins.deepSeq normalized {
    schemaVersion = 1;
    instances = normalized;
  }
