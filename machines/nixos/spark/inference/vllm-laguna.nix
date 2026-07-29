{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vllm-laguna;

  vllmVersion = "0.25.1";
  flashinferVersion = "0.6.15.dev20260712";
  image = "localhost/vllm-laguna:${vllmVersion}";
  speculativeConfig = builtins.toJSON {
    model = "/draft";
    num_speculative_tokens = cfg.numSpeculativeTokens;
    method = "dflash";
  };

  containerfileContents = ''
    FROM docker.io/nvidia/cuda@sha256:450d11555d20ac8ebbbc13ebf17589c2bd42869171a90179ce7098b4a5e64c6a

    LABEL org.opencontainers.image.title="vLLM for Laguna S 2.1 on DGX Spark"
    LABEL org.opencontainers.image.version="${vllmVersion}"

    ENV DEBIAN_FRONTEND=noninteractive
    RUN apt-get update \
      && apt-get install --yes --no-install-recommends \
        build-essential \
        ca-certificates \
        git \
        libnuma1 \
        python3.12 \
        python3.12-dev \
        python3-pip \
      && rm -rf /var/lib/apt/lists/*

    RUN python3.12 -m pip install --break-system-packages "uv==0.11.31" \
      && uv venv /opt/vllm --python /usr/bin/python3.12 \
      && uv pip install --python /opt/vllm/bin/python \
        "vllm==${vllmVersion}" \
        --torch-backend=cu130 \
      && uv pip install --python /opt/vllm/bin/python \
        "flashinfer-python==${flashinferVersion}" \
        "flashinfer-cubin==${flashinferVersion}" \
        "flashinfer-jit-cache==${flashinferVersion}" \
        --extra-index-url https://flashinfer.ai/whl/nightly/ \
        --extra-index-url https://flashinfer.ai/whl/nightly/cu130/ \
        --index-strategy unsafe-best-match \
      && rm -rf /root/.cache/uv

    ENV PATH=/opt/vllm/bin:/usr/local/cuda/bin:$PATH
    ENTRYPOINT ["/opt/vllm/bin/vllm", "serve"]
  '';

  recipeHash = builtins.substring 0 16 (builtins.hashString "sha256" containerfileContents);
  containerfile = pkgs.writeText "vllm-laguna.Containerfile" containerfileContents;
  buildContext = pkgs.runCommand "vllm-laguna-build-context" {} ''
    mkdir "$out"
  '';
in {
  options.services.vllm-laguna = {
    enable = lib.mkEnableOption "Laguna S 2.1 vLLM server";

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start the server automatically when both model directories exist.";
    };

    modelPath = lib.mkOption {
      type = lib.types.str;
      default = "/srv/models/poolside-Laguna-S-2.1-NVFP4";
      description = "Host path containing the target model snapshot.";
    };

    draftModelPath = lib.mkOption {
      type = lib.types.str;
      default = "/srv/models/poolside-Laguna-S-2.1-DFlash-NVFP4";
      description = "Host path containing the DFlash draft model snapshot.";
    };

    numSpeculativeTokens = lib.mkOption {
      type = lib.types.ints.between 1 15;
      default = 15;
      description = "Number of tokens proposed by the DFlash draft model per step.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address for the OpenAI-compatible API.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port for the OpenAI-compatible API.";
    };

    maxModelLen = lib.mkOption {
      type = lib.types.ints.positive;
      default = 262144;
      description = "Maximum context length in tokens.";
    };

    gpuMemoryUtilization = lib.mkOption {
      type = lib.types.float;
      default = 0.85;
      description = "Fraction of unified GPU memory available to vLLM.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.modelPath;
        message = "services.vllm-laguna.modelPath must be an absolute path";
      }
      {
        assertion = lib.hasPrefix "/" cfg.draftModelPath;
        message = "services.vllm-laguna.draftModelPath must be an absolute path";
      }
      {
        assertion = cfg.gpuMemoryUtilization > 0.0 && cfg.gpuMemoryUtilization <= 1.0;
        message = "services.vllm-laguna.gpuMemoryUtilization must be in (0, 1]";
      }
    ];

    networking.firewall.allowedTCPPorts = [cfg.port];

    systemd.tmpfiles.rules = [
      "d /var/cache/vllm-laguna 0755 root root -"
    ];

    systemd.services.vllm-laguna-image = {
      description = "Build the Laguna vLLM container image";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];

      path = [pkgs.podman];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "infinity";
      };

      script = ''
        installed_recipe="$(
          podman image inspect \
            --format '{{ index .Labels "org.nixos.vllm-laguna.recipe" }}' \
            ${lib.escapeShellArg image} 2>/dev/null || true
        )"

        if [[ "$installed_recipe" == ${lib.escapeShellArg recipeHash} ]]; then
          echo "${image} already matches recipe ${recipeHash}"
          exit 0
        fi

        podman build \
          --pull=missing \
          --label ${lib.escapeShellArg "org.nixos.vllm-laguna.recipe=${recipeHash}"} \
          --tag ${lib.escapeShellArg image} \
          --file ${containerfile} \
          ${buildContext}
      '';
    };

    virtualisation.oci-containers = {
      backend = "podman";
      containers.vllm-laguna = {
        inherit image;
        autoStart = cfg.autoStart;
        pull = "never";
        devices = ["nvidia.com/gpu=all"];
        networks = ["host"];
        volumes = [
          "${cfg.modelPath}:/model:ro"
          "${cfg.draftModelPath}:/draft:ro"
          "/var/cache/vllm-laguna:/root/.cache"
        ];
        environment = {
          CUDA_HOME = "/usr/local/cuda";
          CUTE_DSL_ARCH = "sm_121a";
          HF_HUB_OFFLINE = "1";
          MAX_JOBS = "4";
          NIXOS_VLLM_IMAGE_RECIPE = recipeHash;
          VLLM_NO_USAGE_STATS = "1";
        };
        extraOptions = ["--ipc=host"];
        cmd = [
          "/model"
          "--served-model-name"
          "poolside/Laguna-S-2.1-NVFP4"
          "--host"
          cfg.listenAddress
          "--port"
          (toString cfg.port)
          "--speculative-config"
          speculativeConfig
          "--enable-auto-tool-choice"
          "--tool-call-parser"
          "poolside_v1"
          "--reasoning-parser"
          "poolside_v1"
          "--default-chat-template-kwargs"
          ''{"enable_thinking":true}''
          "--override-generation-config"
          ''{"temperature":0.7,"top_p":0.95}''
          "--max-num-seqs"
          "32"
          "--max-model-len"
          (toString cfg.maxModelLen)
          "--gpu-memory-utilization"
          (toString cfg.gpuMemoryUtilization)
        ];
      };
    };

    systemd.services.podman-vllm-laguna = {
      requires = [
        "nvidia-container-toolkit-cdi-generator.service"
        "vllm-laguna-image.service"
      ];
      after = [
        "nvidia-container-toolkit-cdi-generator.service"
        "vllm-laguna-image.service"
      ];
      unitConfig.ConditionPathIsDirectory = [
        cfg.modelPath
        cfg.draftModelPath
      ];
    };
  };
}
