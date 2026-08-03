{lib}: recipes: let
  hash = value: builtins.hashString "sha256" (builtins.toJSON value);
  validName = name: builtins.match "[a-z0-9]([a-z0-9-]*[a-z0-9])?" name != null;
  names = builtins.sort builtins.lessThan (builtins.attrNames recipes);
  normalizeRecipe = import ./lib/normalize-recipe.nix {inherit lib;};

  finalize = name: declaration:
    assert lib.assertMsg (validName name) "recipe names must be kebab-case"; let
      recipe = normalizeRecipe declaration;
      context = builtins.path {
        path = recipe.image.context;
        name = "inference-build-context";
      };
      containerfile = builtins.path {
        path = recipe.image.containerfile;
        name = "inference-Containerfile";
      };
      buildIdentity = {
        schemaVersion = 1;
        inherit (recipe.image) platform buildArgs;
        context = toString context;
        containerfile = toString containerfile;
      };
      image = {
        inherit (buildIdentity) platform buildArgs context containerfile;
        buildHash = hash buildIdentity;
      };
      value = {
        schemaVersion = 1;
        inherit name;
        inherit (recipe) models topology container endpoint;
        inherit image;
      };
    in
      value // {recipeHash = hash value;};
in {
  schemaVersion = 1;
  recipes = map (name: finalize name recipes.${name}) names;
}
