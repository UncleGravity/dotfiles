{config, ...}: let
  modelRoot = "/cache/model";
  cacheRoot = "/var/cache/glm52-b12x-spark";
  port = 18089;
  instances = builtins.attrValues config.my.inference.instances;
  enabled = builtins.any (instance: instance.recipe == "glm52-b12x-spark") instances;
  speculativeConfig = builtins.toJSON {
    model = modelRoot;
    method = "mtp";
    num_speculative_tokens = 4;
    moe_backend = "flashinfer_cutlass";
    draft_attention_backend = "B12X_MLA_SPARSE";
    draft_sample_method = "probabilistic";
  };
  hfOverrides = builtins.toJSON {
    use_index_cache = true;
    index_topk_pattern = "FFFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSS";
  };
in {
  assertions = [
    {
      assertion =
        !enabled
        || !config.my.inference.protectHostMemory
        || config.my.inference.memoryMaxPercent >= 95;
      message = "glm52-b12x-spark requires my.inference.memoryMaxPercent >= 95 when host memory protection is enabled";
    }
  ];

  systemd.tmpfiles.rules = [
    "d ${cacheRoot} 0755 root root -"
    "d ${cacheRoot}/tmp 0755 root root -"
  ];

  my.inference.recipes.glm52-b12x-spark = {
    models = {
      base = {
        repo = "Mapika/GLM-5.2-NVFP4";
        revision = "5f9c62a4b08c36a174055facbd1e0c39b832059f";
      };
      mtp = {
        repo = "sant1an/GLM-5.2-NVFP4-MTP";
        revision = "fe599fc53f999554d4fde99ecee3ef73eb897a3e";
      };
    };

    image = {
      context = ./.;
      buildArgs = {
        VLLM_REPO = "https://github.com/m9e/vllm.git";
        VLLM_COMMIT = "a663653d8cf3a66ee3c0060aea8c2fd28e3f1362";
        B12X_REPO = "https://github.com/voipmonitor/b12x.git";
        B12X_COMMIT = "9cd63a726e9b188701f3dff0e6b95d7814c42fc5";
      };
    };

    topology = {
      nodeCounts = [4];
      startOrder = "head-first";
    };

    container = {
      devices = [
        "nvidia.com/gpu=all"
        "/dev/infiniband/uverbs0"
      ];
      extraOptions = [
        "--ipc=host"
        "--ulimit=memlock=-1:-1"
        "--ulimit=stack=67108864:67108864"
      ];
      environment = {
        B12X_DENSE_SPLITK_TURBO = "0";
        B12X_MOE_FORCE_A16 = "0";
        B12X_W4A16_TC_DECODE = "0";
        CUDA_DEVICE_MAX_CONNECTIONS = "32";
        CUDA_DEVICE_ORDER = "PCI_BUS_ID";
        CUTE_DSL_ARCH = "sm_121a";
        FLASHINFER_CUDA_ARCH_LIST = "12.1a";
        GLOO_SOCKET_IFNAME = "fabric0";
        HF_HOME = "/cache/huggingface";
        NCCL_DEBUG = "WARN";
        NCCL_IB_ADDR_FAMILY = "AF_INET";
        NCCL_IB_DISABLE = "0";
        NCCL_IB_HCA = "=mlx5_0:1";
        NCCL_IB_ROCE_VERSION_NUM = "2";
        NCCL_IGNORE_CPU_AFFINITY = "1";
        NCCL_MAX_NCHANNELS = "4";
        NCCL_MIN_NCHANNELS = "4";
        NCCL_NET = "IB";
        NCCL_SOCKET_IFNAME = "fabric0";
        PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True";
        RAY_DEDUP_LOGS = "0";
        "RAY_memory_monitor_refresh_ms" = "0";
        "RAY_memory_usage_threshold" = "0.99";
        SAFETENSORS_FAST_GPU = "1";
        TORCH_CUDA_ARCH_LIST = "12.1a";
        TRANSFORMERS_OFFLINE = "1";
        TRITON_CACHE_DIR = "/cache/triton";
        USES_B12X = "True";
        VLLM_CACHE_ROOT = "/cache/vllm";
        VLLM_DCP_GLOBAL_TOPK = "1";
        VLLM_DCP_SHARD_DRAFT = "1";
        VLLM_DISABLE_TP_MQ_BROADCASTER = "1";
        VLLM_ENABLE_PCIE_ALLREDUCE = "0";
        VLLM_KZ_TRIM_AFTER_LOAD = "1";
        VLLM_NO_USAGE_STATS = "1";
        VLLM_USE_B12X_FP8_GEMM = "0";
        VLLM_USE_B12X_MOE = "0";
        VLLM_USE_B12X_SPARSE_INDEXER = "1";
        VLLM_USE_DEEP_GEMM = "0";
        VLLM_USE_FLASHINFER_SAMPLER = "1";
        VLLM_WORKER_MULTIPROC_METHOD = "spawn";
      };
      mounts = [
        {
          sourcePath = cacheRoot;
          targetPath = "/cache";
          readOnly = false;
        }
        {
          sourcePath = "${cacheRoot}/tmp";
          targetPath = "/tmp";
          readOnly = false;
        }
      ];
      args = [
        "--model"
        modelRoot
        "--tokenizer"
        modelRoot
        "--served-model-name"
        "glm52-spark4-dcp4-mtp4-128k"
        "--host"
        "0.0.0.0"
        "--port"
        (toString port)
        "--trust-remote-code"
        "--download-dir"
        modelRoot
        "--load-format"
        "auto"
        "--quantization"
        "modelopt_fp4"
        "--distributed-executor-backend"
        "ray"
        "--tensor-parallel-size"
        "4"
        "--pipeline-parallel-size"
        "1"
        "--decode-context-parallel-size"
        "4"
        "--dcp-comm-backend"
        "ag_rs"
        "--dcp-kv-cache-interleave-size"
        "1"
        "--max-model-len"
        "131072"
        "--max-num-seqs"
        "4"
        "--max-num-batched-tokens"
        "1024"
        "--max-cudagraph-capture-size"
        "20"
        "--gpu-memory-utilization"
        "0.89"
        "--kv-cache-memory-bytes"
        "1810000000"
        "--kv-cache-dtype"
        "fp8_ds_mla"
        "--enable-prefix-caching"
        "--generation-config"
        "vllm"
        "--hf-overrides"
        hfOverrides
        "--attention-backend"
        "B12X_MLA_SPARSE"
        "--moe-backend"
        "flashinfer_cutlass"
        "--speculative-config"
        speculativeConfig
        "--no-enable-log-requests"
      ];
    };

    endpoint = {
      inherit port;
      startupTimeoutSeconds = 3600;
    };
  };
}
