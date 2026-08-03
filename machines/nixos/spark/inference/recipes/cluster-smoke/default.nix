let
  port = 18080;
in {
  my.inference.recipes.cluster-smoke = {
    models.fixture = {
      repo = "poolside/Laguna-S-2.1-DFlash-NVFP4";
      revision = "723794750422b3efbf3a7b3af76dffb4ba035943";
    };

    image.context = ./.;

    topology = {
      nodeCounts = [2];
      startOrder = "parallel";
    };

    endpoint = {
      inherit port;
      startupTimeoutSeconds = 120;
    };
  };
}
