{
  clanLib,
  lib,
  ...
}: let
  stripNewlines = builtins.replaceStrings ["\n" "\r"] ["" ""];

  exactlyOne = instanceName: roleName: machines: let
    names = lib.attrNames machines;
  in
    if lib.length names == 1
    then lib.head names
    else throw "Spark cluster '${instanceName}' requires exactly one ${roleName}";

  unique = values: lib.length values == lib.length (lib.unique values);

  mkTopology = {
    directory,
    instanceName,
    roles,
  }: let
    members = roles.node.machines or {};
    controlNode = exactlyOne instanceName "controller" (roles.controller.machines or {});
    monitorName = exactlyOne instanceName "monitor" (roles.monitor.machines or {});
    monitorSettings = roles.monitor.machines.${monitorName}.settings;
    coordinationGenerator = "spark-coordination-${instanceName}";
    huggingfaceGenerator = "spark-huggingface-${instanceName}";
    readPublicValue = machine: generator: file:
      stripNewlines (clanLib.getPublicValue {
        inherit machine generator file;
        flake = directory;
      });
    nodes =
      lib.mapAttrs (name: member: let
        inherit (member) settings;
      in {
        inherit (settings) id managementAddress managementMac;
        controller = name == controlNode;
        sshHostKey = readPublicValue name "openssh" "ssh.id_ed25519.pub";
        fabric = {
          fabric0 = "10.100.0.${toString settings.id}";
          fabric1 = "10.100.1.${toString settings.id}";
        };
      })
      members;
    nodeValues = lib.attrValues nodes;
    orderedNodes = lib.sort (left: right: nodes.${left}.id < nodes.${right}.id) (lib.attrNames nodes);
    inferenceNodes =
      lib.mapAttrs (_: node: {
        platform = "linux/arm64";
        inherit (node) managementAddress sshHostKey fabric;
      })
      nodes;
    fabricHosts = lib.foldlAttrs (hosts: name: node:
      hosts
      // {
        ${node.fabric.fabric0} = ["${name}-f0"];
        ${node.fabric.fabric1} = ["${name}-f1"];
      }) {}
    nodes;
  in
    assert lib.assertMsg (instanceName == "spark")
    "Spark cluster instance must remain named 'spark' to preserve its generator IDs";
    assert lib.assertMsg (lib.length nodeValues == 4)
    "Spark cluster '${instanceName}' currently requires exactly four nodes";
    assert lib.assertMsg (builtins.hasAttr controlNode nodes)
    "Spark controller '${controlNode}' must also have the node role";
    assert lib.assertMsg (unique (map (node: node.id) nodeValues))
    "Spark cluster '${instanceName}' has duplicate node IDs";
    assert lib.assertMsg (unique (map (node: node.managementAddress) nodeValues))
    "Spark cluster '${instanceName}' has duplicate management addresses";
    assert lib.assertMsg (unique (map (node: node.managementMac) nodeValues))
    "Spark cluster '${instanceName}' has duplicate management MACs";
    assert lib.assertMsg (unique (map (node: node.sshHostKey) nodeValues))
    "Spark cluster '${instanceName}' has duplicate SSH host keys";
    assert lib.assertMsg (lib.all (node: lib.hasPrefix "ssh-ed25519 " node.sshHostKey) nodeValues)
    "Spark cluster '${instanceName}' requires Ed25519 SSH host keys"; {
      inherit
        controlNode
        coordinationGenerator
        fabricHosts
        huggingfaceGenerator
        inferenceNodes
        instanceName
        nodes
        orderedNodes
        ;
      coordinationPublicKey = readPublicValue controlNode coordinationGenerator "id_ed25519.pub";
      monitor = {
        name = monitorName;
        inherit
          (monitorSettings)
          gpuExporterPort
          nodeExporterPort
          sourceAddress
          ;
      };
    };

  clusterOption = lib.mkOption {
    type = lib.types.raw;
    readOnly = true;
    description = "Normalized Spark cluster topology supplied by Clan.";
  };
in {
  _class = "clan.service";

  manifest = {
    name = "spark-cluster";
    description = "DGX Spark cluster topology and coordination";
    readme = "Defines the Spark fabric, inference topology, and monitoring targets.";
    categories = ["System"];
    constraints = {
      maxInstances = 1;
      roles = {
        node = {
          minMachines = 4;
          maxMachines = 4;
        };
        controller = {
          minMachines = 1;
          maxMachines = 1;
        };
        monitor = {
          minMachines = 1;
          maxMachines = 1;
        };
      };
    };
  };

  roles = {
    node = {
      description = "A DGX Spark compute node.";

      interface = {lib, ...}: {
        options = {
          id = lib.mkOption {
            type = lib.types.ints.between 1 254;
            description = "Node ID used in both fabric /24 networks.";
          };
          managementAddress = lib.mkOption {
            type = lib.types.nonEmptyStr;
            description = "Management IPv4 address.";
          };
          managementMac = lib.mkOption {
            type = lib.types.strMatching "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}";
            description = "Permanent management-interface MAC address.";
          };
        };
      };

      perInstance = {
        instanceName,
        machine,
        roles,
        ...
      }: {
        nixosModule = {
          config,
          lib,
          ...
        }: let
          topology = mkTopology {
            directory = config.clan.core.settings.directory;
            inherit instanceName roles;
          };
        in {
          imports = [../../nixos/profiles/spark];
          options.my.sparkCluster = clusterOption;
          config = {
            my.sparkCluster =
              topology
              // {
                localNode = topology.nodes.${machine.name};
                isController = machine.name == topology.controlNode;
              };
            sops.age.sshKeyPaths = lib.mkForce [];
          };
        };
      };
    };

    controller = {
      description = "The single Spark inference controller.";

      perInstance = {
        instanceName,
        machine,
        roles,
        ...
      }: let
        controlNode = exactlyOne instanceName "controller" (roles.controller.machines or {});
        coordinationGenerator = "spark-coordination-${instanceName}";
        huggingfaceGenerator = "spark-huggingface-${instanceName}";
      in {
        nixosModule = {
          pkgs,
          username,
          ...
        }: {
          assertions = [
            {
              assertion = machine.name == controlNode;
              message = "Spark controller role must resolve to '${controlNode}'";
            }
          ];

          clan.core.vars.generators = {
            ${coordinationGenerator} = {
              files = {
                id_ed25519.neededFor = "services";
                "id_ed25519.pub".secret = false;
              };
              runtimeInputs = [pkgs.openssh];
              script = ''
                ssh-keygen -t ed25519 -N "" -C "" -f "$out/id_ed25519"
                ssh-keygen -y -f "$out/id_ed25519" > "$out/id_ed25519.pub"
              '';
            };

            ${huggingfaceGenerator} = {
              prompts.token = {
                description = "Hugging Face token for the Spark controller";
                type = "hidden";
                persist = true;
              };
              files.token = {
                owner = username;
                mode = "0400";
              };
              script = ''
                test -s "$out/token"
              '';
            };
          };
        };
      };
    };

    monitor = {
      description = "Prometheus server for Spark exporters.";

      interface = {lib, ...}: {
        options = {
          sourceAddress = lib.mkOption {
            type = lib.types.nonEmptyStr;
            description = "Monitor address allowed through node firewalls.";
          };
          nodeExporterPort = lib.mkOption {
            type = lib.types.port;
            default = 9100;
            description = "Node exporter port.";
          };
          gpuExporterPort = lib.mkOption {
            type = lib.types.port;
            default = 9835;
            description = "NVIDIA GPU exporter port.";
          };
        };
      };

      perInstance = {
        instanceName,
        roles,
        ...
      }: {
        nixosModule = {
          config,
          lib,
          ...
        }: {
          options.my.sparkCluster = clusterOption;
          config.my.sparkCluster = mkTopology {
            directory = config.clan.core.settings.directory;
            inherit instanceName roles;
          };
        };
      };
    };
  };
}
