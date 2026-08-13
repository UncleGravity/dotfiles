{
  inferenceLib,
  inferencePackage,
  kiwiConfiguration,
  pkgs,
  sparkConfiguration,
  sparkConfigurations,
}: let
  inherit (pkgs) lib;
  fixture = import ./fixture.nix {
    inherit inferenceLib pkgs;
  };
  controller = sparkConfiguration.config;
  sparkNames = [
    "spark-01"
    "spark-02"
    "spark-03"
    "spark-04"
  ];
  stripNewlines = builtins.replaceStrings ["\n" "\r"] ["" ""];
  sparkConfigs = lib.mapAttrs (_: configuration: configuration.config) sparkConfigurations;
  expectedNodes = {
    spark-01 = {
      id = 1;
      managementAddress = "192.168.1.31";
      managementMac = "4c:bb:47:2e:47:8c";
    };
    spark-02 = {
      id = 2;
      managementAddress = "192.168.1.32";
      managementMac = "4c:bb:47:2e:35:8c";
    };
    spark-03 = {
      id = 3;
      managementAddress = "192.168.1.33";
      managementMac = "4c:bb:47:2f:83:13";
    };
    spark-04 = {
      id = 4;
      managementAddress = "192.168.1.34";
      managementMac = "4c:bb:47:2e:e0:b0";
    };
  };
  expectedFabric = id: {
    fabric0 = "10.100.0.${toString id}";
    fabric1 = "10.100.1.${toString id}";
  };
  expectedFabricHosts = lib.foldlAttrs (hosts: name: node: let
    fabric = expectedFabric node.id;
  in
    hosts
    // {
      ${fabric.fabric0} = ["${name}-f0"];
      ${fabric.fabric1} = ["${name}-f1"];
    }) {}
  expectedNodes;
  expectedInstances = {
    deepseek-v4-flash-0731 = {
      autoStart = false;
      nodes = ["spark-01" "spark-02"];
      recipe = "deepseek-v4-flash-0731";
    };
    glm52 = {
      autoStart = false;
      nodes = sparkNames;
      recipe = "glm52-b12x-spark";
    };
    laguna = {
      autoStart = false;
      nodes = ["spark-01"];
      recipe = "laguna-vllm";
    };
  };
  sparkScrapeJobs =
    map (job: {
      inherit
        (job)
        job_name
        scrape_interval
        scrape_timeout
        static_configs
        ;
    }) (lib.filter (
        job: lib.elem job.job_name ["spark-node" "spark-gpu"]
      )
      kiwiConfiguration.config.services.prometheus.scrapeConfigs);
  mkStaticConfigs = port:
    map (name: {
      targets = ["${expectedNodes.${name}.managementAddress}:${toString port}"];
      labels = {
        cluster = "spark";
        node = name;
      };
    })
    sparkNames;
  rejects = module: let
    evaluation = (sparkConfiguration.extendModules {modules = [module];}).config.system.build.toplevel.drvPath;
    result = builtins.tryEval evaluation;
  in
    !result.success;
  moduleContract = assert lib.hasInfix "inference-configured" controller.systemd.services.infer-glm52.serviceConfig.ExecStart;
  assert controller.systemd.services.infer-glm52.environment.HF_TOKEN_PATH
  == "/run/secrets/vars/spark-huggingface-spark/token";
  assert rejects {my.inference.coordination.identityFile = lib.mkForce null;};
  assert rejects {my.inference.coordination.authorizedKeys = lib.mkForce [];};
  assert rejects {my.inference.nodes.spark-02.sshHostKey = lib.mkForce null;};
    pkgs.runCommand "inference-module-contract" {} ''
      touch $out
    '';
  topologyContract = assert lib.all (name: let
    config = sparkConfigs.${name};
    expected = expectedNodes.${name};
    actual = config.my.sparkCluster.localNode;
    opensshPublic = stripNewlines config.clan.core.vars.generators.openssh.files."ssh.id_ed25519.pub".value;
    inferenceInstances =
      lib.mapAttrs (_: instance: {
        inherit (instance) autoStart nodes recipe;
      })
      config.my.inference.instances;
  in
    actual.id
    == expected.id
    && actual.managementAddress == expected.managementAddress
    && actual.managementMac == expected.managementMac
    && actual.fabric == expectedFabric expected.id
    && actual.sshHostKey == opensshPublic
    && config.my.sparkCluster.controlNode == "spark-01"
    && config.my.sparkCluster.orderedNodes == sparkNames
    && config.my.sparkCluster.fabricHosts == expectedFabricHosts
    && config.my.inference.controlNode == "spark-01"
    && inferenceInstances == expectedInstances
    && config.services.prometheus.exporters.node.listenAddress == expected.managementAddress
    && config.services.prometheus.exporters.node.port == 9100
    && config.services.prometheus.exporters.nvidia-gpu.listenAddress == expected.managementAddress
    && config.services.prometheus.exporters.nvidia-gpu.port == 9835
    && lib.sort builtins.lessThan config.networking.firewall.trustedInterfaces
    == ["fabric0" "fabric1" "lo" "podman+"]
    && config.services.dgx-dashboard.enable == (name == "spark-01")
    && config.services.dockerRegistry.enable == (name == "spark-01")
    && (config.clan.core.vars.generators ? spark-coordination-spark) == (name == "spark-01")
    && (config.clan.core.vars.generators ? spark-huggingface-spark) == (name == "spark-01")
    && config.sops.age.sshKeyPaths == [])
  sparkNames;
  assert controller.my.inference.coordination.identityFile
  == "/run/secrets/vars/spark-coordination-spark/id_ed25519";
  assert controller.my.inference.serviceEnvironment.HF_TOKEN_PATH
  == "/run/secrets/vars/spark-huggingface-spark/token";
  assert controller.services.dockerRegistry.listenAddress == "10.100.0.1";
  assert sparkScrapeJobs
  == [
    {
      job_name = "spark-node";
      scrape_interval = "5s";
      scrape_timeout = "4s";
      static_configs = mkStaticConfigs 9100;
    }
    {
      job_name = "spark-gpu";
      scrape_interval = "5s";
      scrape_timeout = "4s";
      static_configs = mkStaticConfigs 9835;
    }
  ];
    pkgs.runCommand "spark-topology-contract" {} ''
      touch $out
    '';
in
  assert fixture.invalidRecipeRejected;
  assert fixture.invalidInventoryRejected;
  assert fixture.invalidInstanceRejected; {
    inference = inferencePackage;
    inference-module-contract = moduleContract;
    spark-topology-contract = topologyContract;
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
