{
  inferenceLib,
  inferencePackage,
  pkgs,
  sparkConfiguration,
}: let
  inherit (pkgs) lib;
  fixture = import ./fixture.nix {
    inherit inferenceLib pkgs;
  };
  controller = sparkConfiguration.config;
  rejects = module:
    !(builtins.tryEval (
      (sparkConfiguration.extendModules {modules = [module];}).config.system.build.toplevel.drvPath
    )).success;
  moduleContract = assert lib.hasInfix "inference-configured" controller.systemd.services.infer-glm52.serviceConfig.ExecStart;
  assert controller.systemd.services.infer-glm52.environment.HF_TOKEN_PATH
  == "/run/secrets/vars/spark-huggingface-spark/token";
  assert rejects {my.inference.coordination.identityFile = lib.mkForce null;};
  assert rejects {my.inference.coordination.authorizedKeys = lib.mkForce [];};
  assert rejects {my.inference.nodes.spark-02.sshHostKey = lib.mkForce null;};
    pkgs.runCommand "inference-module-contract" {} ''
      touch $out
    '';
in
  assert fixture.invalidRecipeRejected;
  assert fixture.invalidInventoryRejected;
  assert fixture.invalidInstanceRejected; {
    inference = inferencePackage;
    inference-module-contract = moduleContract;
    inference-contracts =
      pkgs.runCommand "inference-contracts" {
        nativeBuildInputs = [inferencePackage pkgs.jq];
      } ''
        infer recipes list \
          --catalog ${fixture.catalogFile} \
          --json > recipes.json

        models --help > /dev/null
        infer instances list \
          --instances ${fixture.instancesFile} \
          --json > instances.json
        infer watch --help > /dev/null
        test -x ${inferencePackage}/bin/infer-instance
        test -x ${inferencePackage}/bin/infer-cluster
        test -x ${inferencePackage}/bin/infer-prepare
        test -x ${inferencePackage}/bin/infer-remote

        infer plan fixture \
          --catalog ${fixture.catalogFile} \
          --inventory ${fixture.inventoryFile} \
          --instances ${fixture.instancesFile} \
          --json > plan-a.json

        infer plan fixture \
          --catalog ${fixture.catalogFile} \
          --inventory ${fixture.inventoryFile} \
          --instances ${fixture.instancesFile} \
          --json > plan-b.json

        diff --unified plan-a.json plan-b.json
        jq --sort-keys --compact-output . \
          ${../fixtures/contracts/v1/nix-run-plan.json} \
          > expected-plan.json
        jq --sort-keys --compact-output . plan-a.json > actual-plan.json
        diff --unified expected-plan.json actual-plan.json
        touch $out
      '';
  }
