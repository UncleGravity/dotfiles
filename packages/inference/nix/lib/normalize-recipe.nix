{lib}: let
  sortStrings = builtins.sort builtins.lessThan;
  sortNumbers = builtins.sort builtins.lessThan;
  uniqueSortedStrings = values: sortStrings (lib.unique values);
  uniqueSortedNumbers = values: sortNumbers (lib.unique values);
  validName = name:
    builtins.match "[a-z0-9]([a-z0-9-]*[a-z0-9])?" name != null;

  normalizeSelection = selection: {
    include = uniqueSortedStrings selection.include;
    exclude = uniqueSortedStrings selection.exclude;
  };

  normalizeModel = name: model: {
    inherit name;
    inherit (model) repo revision;
    selection = normalizeSelection model.selection;
  };

  normalizeMount = mount: {
    inherit (mount) sourcePath targetPath readOnly;
  };
in
  recipe: let
    modelNames = sortStrings (builtins.attrNames recipe.models);
    models = map (name: normalizeModel name recipe.models.${name}) modelNames;
    mounts = map normalizeMount recipe.container.mounts;
    modelMountTargets = map (name: "/models/${name}") modelNames;
    mountTargets = modelMountTargets ++ (map (mount: mount.targetPath) mounts);
    clustered = builtins.any (nodeCount: nodeCount > 1) recipe.topology.nodeCounts;
    startOrder =
      if recipe.topology.startOrder == null
      then "parallel"
      else recipe.topology.startOrder;
  in
    assert lib.assertMsg (modelNames != []) "recipe.models must be non-empty";
    assert lib.assertMsg (builtins.all validName modelNames) "recipe model names must be kebab-case";
    assert lib.assertMsg (!clustered || recipe.topology.startOrder != null) "clustered recipes must declare recipe.topology.startOrder";
    assert lib.assertMsg (builtins.pathExists (recipe.image.context + "/Containerfile")) "recipe image context must contain Containerfile";
    assert lib.assertMsg (lib.unique mountTargets == mountTargets) "recipe mount target paths must be unique"; {
      schemaVersion = 1;
      inherit models;
      image = {
        inherit (recipe.image) platform context buildArgs;
        containerfile = recipe.image.context + "/Containerfile";
      };
      topology = {
        nodeCounts = uniqueSortedNumbers recipe.topology.nodeCounts;
        inherit startOrder;
      };
      container = {
        devices = uniqueSortedStrings recipe.container.devices;
        extraOptions = lib.unique recipe.container.extraOptions;
        inherit (recipe.container) environment args;
        inherit mounts;
      };
      inherit (recipe) endpoint;
    }
