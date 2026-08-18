{
  inferenceLib,
  inferencePackage,
  nixosLib,
  nixosPkgs,
  pkgs,
}: let
  inherit (pkgs) lib;
  fixture = import ./fixture.nix {
    inherit inferenceLib pkgs;
  };
  localPlatform =
    if nixosPkgs.stdenv.hostPlatform.isx86_64
    then "linux/amd64"
    else "linux/arm64";
  nodeNames = [
    "node-a"
    "node-b"
    "node-c"
    "node-d"
  ];
  nodes = {
    node-a = {
      platform = localPlatform;
      managementAddress = "192.0.2.1";
      sshHostKey = "ssh-ed25519 node-a-key";
      fabric.fabric0 = "198.51.100.1";
    };
    node-b = {
      platform = localPlatform;
      managementAddress = "192.0.2.2";
      sshHostKey = "ssh-ed25519 node-b-key";
      fabric.fabric0 = "198.51.100.2";
    };
    node-c = {
      platform = localPlatform;
      managementAddress = "192.0.2.3";
      sshHostKey = "ssh-ed25519 node-c-key";
      fabric.fabric0 = "198.51.100.3";
    };
    node-d = {
      platform = localPlatform;
      managementAddress = "192.0.2.4";
      sshHostKey = "ssh-ed25519 node-d-key";
      fabric.fabric0 = "198.51.100.4";
    };
  };
  instances = {
    single = {
      recipe = "fixture-vllm";
      nodes = ["node-a"];
      autoStart = true;
    };
    dual = {
      recipe = "fixture-vllm";
      nodes = ["node-a" "node-b"];
      autoStart = false;
    };
    quad = {
      recipe = "fixture-vllm";
      nodes = nodeNames;
      autoStart = true;
    };
  };
  recipe = {
    models.target = {
      repo = "example/tiny-model";
      revision = "1111111111111111111111111111111111111111";
    };
    image = {
      context = ../fixtures/build-context;
      buildArgs.VLLM_VERSION = "0.25.1";
    };
    topology = {
      nodeCounts = [1 2 4];
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
    endpoint.port = 8000;
  };
  mkSystem = localNode:
    nixosLib.nixosSystem {
      system = nixosPkgs.stdenv.hostPlatform.system;
      modules = [
        ../../nix/modules
        {
          nixpkgs.config.allowUnfree = true;
          networking.hostName = localNode;
          system.stateVersion = "26.05";

          my.inference = {
            enable = true;
            controlNode = "node-a";
            coordination = {
              authorizedKeys = ["ssh-ed25519 coordination-key"];
              identityFile =
                if localNode == "node-a"
                then "/run/keys/coordination"
                else null;
            };
            inherit instances nodes;
            recipes.fixture-vllm = recipe;
          };
        }
      ];
    };
  controllerConfiguration = mkSystem "node-a";
  workerConfiguration = mkSystem "node-b";
  controller = controllerConfiguration.config;
  worker = workerConfiguration.config;
  expectedModelStoreRules = map (path: "d /srv/models/${path} 2770 root infer -") [
    ".locks"
    ".locks/hf"
    ".locks/images"
    ".staging"
    ".staging/hf"
    "hf"
  ];
  rejects = module: let
    evaluation = (controllerConfiguration.extendModules {modules = [module];}).config.system.build.toplevel.drvPath;
    result = builtins.tryEval evaluation;
  in
    !result.success;
  moduleContract = assert lib.all (rule: builtins.elem rule controller.systemd.tmpfiles.rules) expectedModelStoreRules;
  assert lib.hasInfix "inference-configured" controller.systemd.services.infer-dual.serviceConfig.ExecStart;
  assert controller.systemd.services.infer-single.wantedBy == ["multi-user.target"];
  assert controller.systemd.services.infer-dual.wantedBy == [];
  assert controller.systemd.services.infer-quad.wantedBy == ["multi-user.target"];
  assert builtins.hasAttr "infer-node-dual" controller.systemd.services;
  assert builtins.hasAttr "infer-prepare-dual" controller.systemd.services;
  assert builtins.hasAttr "infer-node-quad" controller.systemd.services;
  assert builtins.hasAttr "infer-prepare-quad" controller.systemd.services;
  assert builtins.hasAttr "infer-node-dual" worker.systemd.services;
  assert builtins.hasAttr "infer-prepare-dual" worker.systemd.services;
  assert builtins.hasAttr "infer-node-quad" worker.systemd.services;
  assert builtins.hasAttr "infer-prepare-quad" worker.systemd.services;
  assert !(builtins.hasAttr "infer-single" worker.systemd.services);
  assert !(builtins.hasAttr "infer-dual" worker.systemd.services);
  assert !(builtins.hasAttr "infer-quad" worker.systemd.services);
  assert rejects {my.inference.coordination.identityFile = lib.mkForce null;};
  assert rejects {my.inference.coordination.authorizedKeys = lib.mkForce [];};
  assert rejects {my.inference.nodes.node-b.sshHostKey = lib.mkForce null;};
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
