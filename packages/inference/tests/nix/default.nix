{
  inferenceLib,
  inferencePackage,
  pkgs,
}: let
  fixture = import ./fixture.nix {
    inherit inferenceLib pkgs;
  };
in
  assert fixture.invalidRecipeRejected;
  assert fixture.invalidInventoryRejected;
  assert fixture.invalidInstanceRejected; {
    inference = inferencePackage;
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
