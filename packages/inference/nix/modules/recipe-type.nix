{
  lib,
  localPlatform,
}: let
  inherit (lib) mkOption types;
  absolutePath = types.addCheck types.nonEmptyStr (lib.hasPrefix "/");
  relativePath = types.addCheck types.nonEmptyStr (value:
    !lib.hasPrefix "/" value
    && !builtins.elem ".." (lib.splitString "/" value));
  repository =
    types.addCheck types.nonEmptyStr (value:
      builtins.match "[^/[:space:]]+/[^/[:space:]]+" value != null);
  revision = types.strMatching "[0-9a-f]{40}";

  selectionType = types.submodule {
    options = {
      include = mkOption {
        type = types.listOf relativePath;
        default = [];
      };
      exclude = mkOption {
        type = types.listOf relativePath;
        default = [];
      };
    };
  };

  modelType = types.submodule {
    options = {
      repo = mkOption {
        type = repository;
        description = "Hugging Face repository in ORG/REPO form";
      };
      revision = mkOption {
        type = revision;
        description = "Exact lowercase Hugging Face commit SHA";
      };
      selection = mkOption {
        type = selectionType;
        default = {};
        description = "Repository files to materialize";
      };
    };
  };

  imageType = types.submodule {
    options = {
      context = mkOption {
        type = types.path;
        description = "Build context containing an adjacent Containerfile";
      };
      platform = mkOption {
        type = types.enum ["linux/amd64" "linux/arm64"];
        default = localPlatform;
        description = "OCI image platform";
      };
      buildArgs = mkOption {
        type = types.attrsOf types.str;
        default = {};
      };
    };
  };

  topologyType = types.submodule {
    options = {
      nodeCounts = mkOption {
        type = types.nonEmptyListOf types.ints.positive;
        default = [1];
        description = "Validated node counts for this workload";
      };
      startOrder = mkOption {
        type = types.nullOr (types.enum ["head-first" "workers-first" "parallel"]);
        default = null;
        description = "Required startup order for a clustered workload";
      };
    };
  };

  mountType = types.submodule {
    options = {
      sourcePath = mkOption {
        type = absolutePath;
      };
      targetPath = mkOption {
        type = absolutePath;
      };
      readOnly = mkOption {
        type = types.bool;
        default = true;
        description = "Mount read-only unless the workload requires persistent writes";
      };
    };
  };

  containerType = types.submodule {
    options = {
      devices = mkOption {
        type = types.listOf types.nonEmptyStr;
        default = [];
      };
      extraOptions = mkOption {
        type = types.listOf types.nonEmptyStr;
        default = [];
      };
      environment = mkOption {
        type = types.attrsOf types.str;
        default = {};
      };
      args = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Arguments passed to the image entrypoint";
      };
      mounts = mkOption {
        type = types.listOf mountType;
        default = [];
      };
    };
  };

  endpointType = types.submodule {
    options = {
      port = mkOption {
        type = types.port;
        description = "Host-networked inference API port";
      };
      healthPath = mkOption {
        type = absolutePath;
        default = "/health";
      };
      startupTimeoutSeconds = mkOption {
        type = types.ints.positive;
        default = 900;
      };
    };
  };
in
  types.submodule {
    options = {
      models = mkOption {
        type = types.attrsOf modelType;
        description = "Models keyed by their recipe-local logical names";
      };
      image = mkOption {
        type = imageType;
      };
      topology = mkOption {
        type = topologyType;
        default = {};
      };
      container = mkOption {
        type = containerType;
        default = {};
      };
      endpoint = mkOption {
        type = endpointType;
      };
    };
  }
