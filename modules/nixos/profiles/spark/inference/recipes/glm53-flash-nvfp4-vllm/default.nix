let
  cacheRoot = "/var/cache/glm53-flash-nvfp4-vllm";
  port = 8888;
in {
  systemd.tmpfiles.rules = [
    "d ${cacheRoot} 0755 root root -"
    "d ${cacheRoot}/tmp 0755 root root -"
  ];

  my.inference.recipes.glm53-flash-nvfp4-vllm = {
    models = {
      model = {
        repo = "nvidia/GLM-5.3-Flash-NVFP4";
        revision = "09b04e5e74bca08ca8549fc736d4cdd8624bfde3";
      };
      draft = {
        repo = "incoai/GLM-5.3-Flash-DFlash2";
        revision = "bf582e4eacc1810f76656d1811693ff6c6737d2a";
      };
    };

    image.context = ./.;

    topology = {
      nodeCounts = [4];
      startOrder = "workers-first";
    };

    container = {
      devices = [
        "nvidia.com/gpu=all"
        "/dev/infiniband/uverbs0"
        "/dev/infiniband/uverbs2"
      ];
      extraOptions = [
        "--ipc=host"
        "--ulimit=memlock=-1:-1"
        "--ulimit=stack=67108864:67108864"
      ];
      environment = {
        CMAKE_BUILD_PARALLEL_LEVEL = "1";
        CUTE_DSL_ARCH = "sm_121a";
        FLASHINFER_CUDA_ARCH_LIST = "12.1a";
        FLASHINFER_WORKSPACE_BASE = "/cache/flashinfer";
        GLOO_SOCKET_IFNAME = "fabric0";
        HOME = "/cache/home";
        HF_HOME = "/cache/huggingface";
        MAX_JOBS = "1";
        NCCL_CROSS_NIC = "1";
        NCCL_CUMEM_ENABLE = "0";
        NCCL_DEBUG = "WARN";
        NCCL_IB_ADDR_FAMILY = "AF_INET";
        NCCL_IB_DISABLE = "0";
        NCCL_IB_HCA = "=mlx5_0:1,mlx5_2:1";
        NCCL_IB_MERGE_NICS = "1";
        NCCL_IB_ROCE_VERSION_NUM = "2";
        NCCL_IGNORE_CPU_AFFINITY = "1";
        NCCL_NET = "IB";
        NCCL_NVLS_ENABLE = "0";
        NCCL_SOCKET_IFNAME = "fabric0";
        PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True";
        TORCHINDUCTOR_COMPILE_THREADS = "1";
        TORCH_CUDA_ARCH_LIST = "12.1a";
        TRANSFORMERS_OFFLINE = "1";
        TRITON_CACHE_DIR = "/cache/triton";
        VLLM_CACHE_ROOT = "/cache/vllm/tp4-dflash5-cache";
        VLLM_NO_USAGE_STATS = "1";
        VLLM_SPARSE_INDEXER_MAX_LOGITS_MB = "64";
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
        "/models/model"
        "--served-model-name"
        "spark-current"
        "--host"
        "0.0.0.0"
        "--port"
        (toString port)
        "--distributed-executor-backend"
        "mp"
        "--distributed-timeout-seconds"
        "3600"
        "--dtype"
        "bfloat16"
        "--moe-backend"
        "b12x"
        "--linear-backend"
        "b12x"
        "--kv-cache-dtype"
        "fp8"
        "--block-size"
        "256"
        "--max-model-len"
        "1048576"
        "--max-num-seqs"
        "8"
        "--max-num-batched-tokens"
        "8192"
        "--max-cudagraph-capture-size"
        "64"
        "--gpu-memory-utilization"
        "0.80"
        "--no-enable-flashinfer-autotune"
        "--mamba-cache-mode"
        "align"
        "--enable-prefix-caching"
        "--enable-prompt-tokens-details"
        "--enable-chunked-prefill"
        "--reasoning-parser"
        "glm45"
        "--tool-call-parser"
        "glm47"
        "--enable-auto-tool-choice"
        "--generation-config"
        "vllm"
        "--prefix-cache-retention-interval"
        "2304"
        "--speculative-config"
        (builtins.toJSON {
          method = "dflash";
          model = "/models/draft";
          num_speculative_tokens = 5;
          attention_backend = "TRITON_ATTN";
          kv_cache_dtype = "auto";
          draft_sample_method = "probabilistic";
          rejection_sample_method = "standard";
          enable_adaptive_verification = false;
          disable_eagle_block_drop = false;
        })
      ];
    };

    endpoint = {
      inherit port;
      startupTimeoutSeconds = 7200;
    };
  };
}
