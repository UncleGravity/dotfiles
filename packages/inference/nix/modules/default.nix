{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.inference;
  inferenceLib = import ../lib {inherit lib;};
  package = pkgs.callPackage ../package.nix {};
  localNode = config.networking.hostName;
  absolutePath = lib.types.addCheck lib.types.nonEmptyStr (lib.hasPrefix "/");
  localPlatform =
    if pkgs.stdenv.hostPlatform.isx86_64
    then "linux/amd64"
    else if pkgs.stdenv.hostPlatform.isAarch64
    then "linux/arm64"
    else throw "my.inference does not support ${pkgs.stdenv.hostPlatform.system}";
  recipeType = import ./recipe-type.nix {inherit lib localPlatform;};
  catalog = inferenceLib.mkCatalog cfg.recipes;
  configuredNodes =
    if cfg.nodes == {}
    then {
      ${localNode} = {
        platform = localPlatform;
        managementAddress = "127.0.0.1";
      };
    }
    else cfg.nodes;
  nodes = lib.mapAttrs (_: node:
    node
    // {
      fabric = lib.filterAttrs (_: value: value != null) (node.fabric or {});
    })
  configuredNodes;
  inventoryNodes = lib.mapAttrs (_: node: removeAttrs node ["sshHostKey"]) nodes;
  localNodeConfig = nodes.${localNode};
  localFabricAddress = localNodeConfig.fabric.fabric0 or null;
  hasFabric = localFabricAddress != null;
  registryPort = 5000;
  registryDataDir = "/var/lib/infer/registry";
  controlNodeConfig = nodes.${cfg.controlNode} or null;
  registryAddress =
    if controlNodeConfig == null
    then "127.0.0.1"
    else controlNodeConfig.fabric.fabric0 or controlNodeConfig.managementAddress;
  registryEndpoint = "${registryAddress}:${toString registryPort}";
  inventory = inferenceLib.mkInventory {
    inherit localNode;
    inherit (cfg) controlNode modelStore;
    nodes = inventoryNodes;
    registry.endpoint = registryEndpoint;
  };
  instanceCatalog = inferenceLib.mkInstanceCatalog {
    inherit (cfg) instances recipes;
    inherit localNode nodes;
  };
  catalogFile = pkgs.writeText "inference-catalog-v1.json" (builtins.toJSON catalog);
  inventoryFile = pkgs.writeText "inference-inventory-v1.json" (builtins.toJSON inventory);
  instancesFile = pkgs.writeText "inference-instances-v1.json" (builtins.toJSON instanceCatalog);
  isRegistryHost = localNode == cfg.controlNode;
  singleInstances = builtins.filter (instance: builtins.length instance.nodes == 1) instanceCatalog.instances;
  clusteredInstances = builtins.filter (instance: builtins.length instance.nodes > 1) instanceCatalog.instances;
  hasClusteredInstances = clusteredInstances != [];
  nodesWithSshHostKeys = lib.filterAttrs (_: node: (node.sshHostKey or null) != null) nodes;
  coordinationEnabled = nodesWithSshHostKeys != {};
  localSingleInstances = builtins.filter (instance: builtins.elem localNode instance.nodes) singleInstances;
  localClusteredInstances = builtins.filter (instance: builtins.elem localNode instance.nodes) clusteredInstances;
  clusteredNodes = lib.unique (builtins.concatMap (instance: instance.nodes) clusteredInstances);
  requiredSshNodes = lib.unique ([cfg.controlNode] ++ clusteredNodes);
  missingSshHostKeys = builtins.filter (nodeName: (nodes.${nodeName}.sshHostKey or null) == null) requiredSshNodes;
  controlPublicKey =
    if controlNodeConfig == null
    then null
    else controlNodeConfig.sshHostKey or null;

  mkNodeService = {
    instance,
    clustered,
  }: let
    usesNvidia = builtins.any (lib.hasPrefix "nvidia.com/gpu=") cfg.recipes.${instance.recipe}.container.devices;
    nvidiaService = "nvidia-container-toolkit-cdi-generator.service";
    unitName =
      if clustered
      then "infer-node-${instance.name}"
      else "infer-${instance.name}";
  in {
    description =
      if clustered
      then "Inference node for ${instance.name}"
      else "Inference instance ${instance.name}";
    after =
      ["network-online.target"]
      ++ lib.optional (!clustered && isRegistryHost) "docker-registry.service"
      ++ lib.optional usesNvidia nvidiaService;
    wants = ["network-online.target"] ++ lib.optional (!clustered && isRegistryHost) "docker-registry.service";
    requires = lib.optional usesNvidia nvidiaService;
    wantedBy = lib.optional (!clustered && instance.autoStart) "multi-user.target";
    restartIfChanged = false;
    restartTriggers = [catalogFile inventoryFile instancesFile];
    path = [package pkgs.podman pkgs.systemd pkgs.util-linux];
    unitConfig = {
      StartLimitIntervalSec = 60;
      StartLimitBurst = 3;
    };
    serviceConfig =
      {
        Type = "notify";
        NotifyAccess = "all";
        ExecStartPre = ["-${pkgs.podman}/bin/podman rm --force --ignore infer-${instance.name}"];
        ExecStart = "${pkgs.util-linux}/bin/flock --exclusive --nonblock --no-fork /var/lib/infer/node.lock ${package}/bin/infer-instance ${instance.name}";
        ExecStop = "-${pkgs.podman}/bin/podman stop --ignore --time 30 infer-${instance.name}";
        ExecStopPost = ["-${pkgs.podman}/bin/podman rm --force --ignore infer-${instance.name}"];
        Restart =
          if clustered
          then "no"
          else "on-failure";
        RestartSec = 5;
        KillMode = "mixed";
        TimeoutStartSec = "infinity";
        TimeoutStopSec = 45;
        UMask = "0007";
      }
      // lib.optionalAttrs cfg.protectHostMemory {
        Slice = "inference.slice";
        MemoryMax = "${toString cfg.memoryMaxPercent}%";
        OOMPolicy = "stop";
        OOMScoreAdjust = 500;
      }
      // lib.optionalAttrs (cfg.protectHostMemory && !cfg.allowSwap) {
        MemorySwapMax = 0;
      };
  };

  singleServices = builtins.listToAttrs (map (instance:
    lib.nameValuePair "infer-${instance.name}" (mkNodeService {
      inherit instance;
      clustered = false;
    }))
  localSingleInstances);
  clusterNodeServices = builtins.listToAttrs (map (instance:
    lib.nameValuePair "infer-node-${instance.name}" (mkNodeService {
      inherit instance;
      clustered = true;
    }))
  localClusteredInstances);
  clusterPrepareServices = builtins.listToAttrs (map (instance:
    lib.nameValuePair "infer-prepare-${instance.name}" {
      description = "Prepare local artifacts for ${instance.name}";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [catalogFile inventoryFile instancesFile];
      path = [package pkgs.podman pkgs.systemd pkgs.util-linux];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${package}/bin/infer-prepare ${instance.name}";
        TimeoutStartSec = "infinity";
        UMask = "0007";
      };
    })
  localClusteredInstances);
  clusterControlServices =
    if isRegistryHost
    then
      builtins.listToAttrs (map (instance:
        lib.nameValuePair "infer-${instance.name}" {
          description = "Inference cluster ${instance.name}";
          after = ["network-online.target" "docker-registry.service"];
          wants = ["network-online.target" "docker-registry.service"];
          restartIfChanged = false;
          restartTriggers = [catalogFile inventoryFile instancesFile];
          wantedBy = lib.optional instance.autoStart "multi-user.target";
          path = [package pkgs.systemd];
          unitConfig = {
            StartLimitIntervalSec = 60;
            StartLimitBurst = 3;
          };
          serviceConfig = {
            Type = "notify";
            NotifyAccess = "all";
            ExecStart = "${package}/bin/infer-cluster ${instance.name}";
            Restart = "no";
            KillMode = "mixed";
            TimeoutStartSec = "infinity";
            TimeoutStopSec = 180;
            UMask = "0007";
          };
        })
      clusteredInstances)
    else {};
  instanceServices = singleServices // clusterNodeServices // clusterPrepareServices // clusterControlServices;

  nodeType = lib.types.submodule {
    options = {
      platform = lib.mkOption {
        type = lib.types.enum ["linux/amd64" "linux/arm64"];
      };
      managementAddress = lib.mkOption {
        type = lib.types.nonEmptyStr;
      };
      sshHostKey = lib.mkOption {
        type = lib.types.nullOr lib.types.nonEmptyStr;
        default = null;
        description = "Pinned SSH public host key for this node";
      };
      fabric = lib.mkOption {
        type = lib.types.submodule {
          options = {
            fabric0 = lib.mkOption {
              type = lib.types.nullOr lib.types.nonEmptyStr;
              default = null;
            };
            fabric1 = lib.mkOption {
              type = lib.types.nullOr lib.types.nonEmptyStr;
              default = null;
            };
          };
        };
        default = {};
      };
    };
  };
  instanceType = lib.types.submodule {
    options = {
      recipe = lib.mkOption {
        type = lib.types.strMatching "[a-z0-9]([a-z0-9-]*[a-z0-9])?";
      };
      nodes = lib.mkOption {
        type = lib.types.nonEmptyListOf (lib.types.strMatching "[a-z0-9]([a-z0-9-]*[a-z0-9])?");
        default = [localNode];
        description = "Nodes allocated to this instance in head-first rank order";
      };
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };
in {
  options.my.inference = {
    enable = lib.mkEnableOption "declarative inference tooling";

    controlNode = lib.mkOption {
      type = lib.types.strMatching "[a-z0-9]([a-z0-9-]*[a-z0-9])?";
      default = localNode;
      description = "Node that prepares shared artifacts and hosts the local registry";
    };
    nodes = lib.mkOption {
      type = lib.types.attrsOf nodeType;
      default = {};
      description = "Deployment nodes; an empty set declares only the local NixOS host";
    };
    recipes = lib.mkOption {
      type = lib.types.attrsOf recipeType;
      default = {};
      description = "Complete inference workloads available to this deployment";
    };
    instances = lib.mkOption {
      type = lib.types.attrsOf instanceType;
      default = {};
      description = "Named inference services declared for this deployment";
    };
    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Users allowed to manage model artifacts and read inference logs";
    };
    protectHostMemory = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Protect the host from inference workload memory exhaustion";
    };
    allowSwap = lib.mkEnableOption "swap for protected inference workloads";
    memoryMaxPercent = lib.mkOption {
      type = lib.types.ints.between 1 100;
      default = 90;
      description = "Per-node systemd memory limit percentage for protected inference workloads";
    };
    modelStore = {
      archiveRoot = lib.mkOption {
        type = absolutePath;
        default = "/mnt/nas/unas/ai/models";
      };
      localRoot = lib.mkOption {
        type = absolutePath;
        default = "/srv/models";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !coordinationEnabled || controlPublicKey != null;
        message = "my.inference.nodes.${cfg.controlNode}.sshHostKey must be configured when coordination is enabled";
      }
      {
        assertion = !hasClusteredInstances || missingSshHostKeys == [];
        message = "my.inference.nodes is missing SSH host keys for clustered nodes: ${lib.concatStringsSep ", " missingSshHostKeys}";
      }
    ];

    environment = {
      etc = {
        "infer/catalog.json".source = catalogFile;
        "infer/inventory.json".source = inventoryFile;
        "infer/instances.json".source = instancesFile;
      };
      systemPackages = [package];
    };

    users = {
      groups =
        {infer = {};}
        // lib.optionalAttrs coordinationEnabled {infer-remote = {};};
      users =
        lib.genAttrs cfg.operators (_: {
          extraGroups = ["infer" "systemd-journal"];
        })
        // lib.optionalAttrs (coordinationEnabled && controlPublicKey != null) {
          infer-remote = {
            isSystemUser = true;
            group = "infer-remote";
            shell = pkgs.bashInteractive;
            openssh.authorizedKeys.keys = [
              ''restrict,command="${package}/bin/infer-remote" ${controlPublicKey}''
            ];
          };
        };
    };

    programs.ssh.knownHosts = lib.mkIf (coordinationEnabled && isRegistryHost) (
      lib.mapAttrs (_: nodeConfig: {
        hostNames = [nodeConfig.managementAddress] ++ builtins.attrValues nodeConfig.fabric;
        publicKey = nodeConfig.sshHostKey;
      })
      nodesWithSshHostKeys
    );

    security.polkit = lib.mkIf coordinationEnabled {
      enable = true;
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (subject.user !== "infer-remote" ||
              action.id !== "org.freedesktop.systemd1.manage-units") {
            return polkit.Result.NOT_HANDLED;
          }

          var unit = action.lookup("unit");
          var verb = action.lookup("verb");
          if (unit && /^infer-(node|prepare)-[a-z0-9]([a-z0-9-]*[a-z0-9])?\.service$/.test(unit) &&
              (verb === "start" || verb === "stop")) {
            return polkit.Result.YES;
          }
        });
      '';
    };

    systemd = {
      tmpfiles.rules =
        [
          "d /var/lib/infer 0755 root root -"
          "d ${cfg.modelStore.localRoot} 2770 root infer -"
        ]
        ++ lib.optional isRegistryHost "d ${registryDataDir} 0750 docker-registry docker-registry -";

      services =
        instanceServices
        // lib.optionalAttrs isRegistryHost {
          docker-registry = {
            after = ["network-online.target"];
            wants = ["network-online.target"];
            environment.OTEL_TRACES_EXPORTER = "none";
          };
        }
        // lib.optionalAttrs hasFabric {
          rsync = {
            after = ["network-online.target"];
            wants = ["network-online.target"];
          };
        };

      slices.inference = lib.mkIf cfg.protectHostMemory {
        description = "Inference workloads";
      };
    };

    virtualisation = {
      podman.enable = true;
      containers = {
        enable = true;
        registries.settings.registry = lib.mkAfter [
          {
            location = registryEndpoint;
            insecure = true;
          }
        ];
      };
    };

    services.dockerRegistry = lib.mkIf isRegistryHost {
      enable = true;
      listenAddress = registryAddress;
      port = registryPort;
      storagePath = registryDataDir;
      enableDelete = false;
      enableGarbageCollect = false;
      openFirewall = false;
    };

    services.openssh.settings = lib.mkIf coordinationEnabled {
      ClientAliveInterval = 10;
      ClientAliveCountMax = 3;
    };

    services.rsyncd = lib.mkIf hasFabric {
      enable = true;
      socketActivated = false;
      port = 873;
      settings = {
        globalSection = {
          address = localFabricAddress;
          uid = "root";
          gid = "infer";
          "use chroot" = true;
          "max connections" = 1;
          "read only" = true;
        };
        sections.models = {
          path = cfg.modelStore.localRoot;
          comment = "Verified local inference model artifacts";
          "read only" = true;
        };
      };
    };
  };
}
