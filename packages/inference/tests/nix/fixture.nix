{
  pkgs,
  inferenceLib ? import ../../nix/lib {inherit (pkgs) lib;},
}: let
  inherit (pkgs) lib;
  recipeType = import ../../nix/modules/recipe-type.nix {
    inherit lib;
    localPlatform = "linux/arm64";
  };
  evaluateRecipes = recipes:
    (lib.evalModules {
      modules = [
        {
          options.recipes = lib.mkOption {
            type = lib.types.attrsOf recipeType;
          };
          config = {inherit recipes;};
        }
      ];
    }).config.recipes;
  recipeInput = {
    models.target = {
      repo = "example/tiny-model";
      revision = "1111111111111111111111111111111111111111";
    };
    image = {
      context = ../fixtures/build-context;
      buildArgs.VLLM_VERSION = "0.25.1";
    };
    topology = {
      nodeCounts = [2 1 2];
      startOrder = "workers-first";
    };
    container = {
      devices = ["nvidia.com/gpu=all"];
      extraOptions = ["--ipc=host"];
      environment.HF_HUB_OFFLINE = "1";
      args = [
        "/models/target"
        "--served-model-name"
        "fixture"
      ];
    };
    endpoint = {
      port = 8000;
    };
  };
  recipes = evaluateRecipes {fixture-vllm = recipeInput;};
  recipe = recipes.fixture-vllm;
  catalog = inferenceLib.mkCatalog recipes;
  inventoryInput = {
    localNode = "node-a";
    controlNode = "node-a";
    modelStore = {
      archiveRoot = "/mnt/nas/unas/ai/models";
      localRoot = "/srv/models";
    };
    registry.endpoint = "198.51.100.1:5000";
    nodes = {
      node-b = {
        platform = "linux/arm64";
        managementAddress = "192.0.2.2";
        fabric = {
          fabric0 = "198.51.100.2";
          fabric1 = "203.0.113.2";
        };
      };
      node-a = {
        platform = "linux/arm64";
        managementAddress = "192.0.2.1";
        fabric = {
          fabric0 = "198.51.100.1";
          fabric1 = "203.0.113.1";
        };
      };
    };
  };
  inventory = inferenceLib.mkInventory inventoryInput;
  instanceCatalog = inferenceLib.mkInstanceCatalog {
    instances.fixture = {
      recipe = "fixture-vllm";
      nodes = ["node-b" "node-a"];
      autoStart = true;
    };
    inherit recipes;
    inherit (inventoryInput) nodes localNode;
  };
  invalidRecipeRejected =
    !(builtins.tryEval (
      builtins.deepSeq
      (evaluateRecipes {
        invalid =
          recipeInput
          // {
            topology = recipeInput.topology // {nodeCounts = [0];};
          };
      })
      true
    )).success;
  invalidInventoryRejected =
    !(builtins.tryEval (
      inferenceLib.mkInventory (inventoryInput // {unknown = true;})
    )).success;
  invalidInstanceRejected =
    !(builtins.tryEval (
      inferenceLib.mkInstanceCatalog {
        instances.fixture.recipe = "missing";
        recipes = {fixture-vllm = recipe;};
        inherit (inventoryInput) nodes localNode;
      }
    )).success;
in {
  inherit catalog instanceCatalog inventory invalidInstanceRejected invalidInventoryRejected invalidRecipeRejected;
  catalogFile = pkgs.writeText "inference-catalog-v1.json" (builtins.toJSON catalog);
  instancesFile = pkgs.writeText "inference-instances-v1.json" (builtins.toJSON instanceCatalog);
  inventoryFile = pkgs.writeText "inference-inventory-v1.json" (builtins.toJSON inventory);
}
