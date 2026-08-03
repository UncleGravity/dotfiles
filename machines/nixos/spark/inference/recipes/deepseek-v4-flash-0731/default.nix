let
  modelRoot = "/models/model";
  cacheRoot = "/var/cache/deepseek-v4-flash-0731";
  port = 8888;
  speculativeConfig = builtins.toJSON {
    method = "dspark";
    num_speculative_tokens = 5;
    draft_sample_method = "probabilistic";
  };
  reasoningConfig = builtins.toJSON {
    reasoning_parser = "deepseek_v4";
    reasoning_start_str = "<think>";
    reasoning_end_str = "</think>";
  };
in {
  systemd.tmpfiles.rules = [
    "d ${cacheRoot} 0755 root root -"
    "d ${cacheRoot}/tmp 0755 root root -"
  ];

  my.inference.recipes.deepseek-v4-flash-0731 = {
    models.model = {
      repo = "deepseek-ai/DeepSeek-V4-Flash-0731";
      revision = "7872f01b1d1fe23eabc4c98b48bffcef5a386062";
    };

    image.context = ./.;

    topology = {
      nodeCounts = [2];
      startOrder = "workers-first";
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
        CUTE_DSL_ARCH = "sm_121a";
        DG_JIT_NVCC_COMPILER = "/usr/local/cuda/bin/nvcc";
        DG_JIT_USE_NVRTC = "0";
        FLASHINFER_CUDA_ARCH_LIST = "12.1a";
        FLASHINFER_DISABLE_VERSION_CHECK = "1";
        FLASHINFER_WORKSPACE_BASE = "/cache/flashinfer";
        GLOO_SOCKET_IFNAME = "fabric0";
        HOME = "/cache/home";
        HF_HOME = "/cache/huggingface";
        HF_HUB_DISABLE_XET = "1";
        NCCL_CROSS_NIC = "1";
        NCCL_CUMEM_ENABLE = "0";
        NCCL_DEBUG = "WARN";
        NCCL_IB_ADDR_FAMILY = "AF_INET";
        NCCL_IB_DISABLE = "0";
        NCCL_IB_HCA = "mlx5_0";
        NCCL_IB_ROCE_VERSION_NUM = "2";
        NCCL_IGNORE_CPU_AFFINITY = "1";
        NCCL_NET = "IB";
        NCCL_NVLS_ENABLE = "0";
        NCCL_SOCKET_IFNAME = "fabric0";
        PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True";
        TILELANG_CLEANUP_TEMP_FILES = "1";
        TORCH_CUDA_ARCH_LIST = "12.1a";
        TP_SOCKET_IFNAME = "fabric0";
        TRANSFORMERS_OFFLINE = "1";
        TRITON_CACHE_DIR = "/cache/triton";
        VLLM_ALLOW_LONG_MAX_MODEL_LEN = "1";
        VLLM_B12X_W4A16_FORCE_BLOCKS_MAX_M = "16";
        VLLM_B12X_W4A16_FORCE_BLOCKS_PER_SM = "0";
        VLLM_CACHE_ROOT = "/cache/vllm";
        VLLM_SPARSE_INDEXER_MAX_LOGITS_MB = "256";
        VLLM_USE_B12X_MOE = "1";
        VLLM_USE_FLASHINFER_SAMPLER = "1";
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
        modelRoot
        "--served-model-name"
        "deepseek-ai/DeepSeek-V4-Flash-0731"
        "--host"
        "0.0.0.0"
        "--port"
        (toString port)
        "--trust-remote-code"
        "--tensor-parallel-size"
        "2"
        "--pipeline-parallel-size"
        "1"
        "--kv-cache-dtype"
        "nvfp4_ds_mla"
        "--block-size"
        "256"
        "--max-model-len"
        "524288"
        "--max-num-seqs"
        "6"
        "--max-num-batched-tokens"
        "8192"
        "--gpu-memory-utilization"
        "0.80"
        "--enforce-eager"
        "--enable-prefix-caching"
        "--enable-prompt-tokens-details"
        "--async-scheduling"
        "--enable-chunked-prefill"
        "--speculative-config"
        speculativeConfig
        "--tokenizer-mode"
        "deepseek_v4"
        "--distributed-executor-backend"
        "mp"
        "--moe-backend"
        "flashinfer_b12x"
        "--tool-call-parser"
        "deepseek_v4"
        "--enable-auto-tool-choice"
        "--reasoning-parser"
        "deepseek_v4"
        "--reasoning-config"
        reasoningConfig
        "--default-chat-template-kwargs"
        ''{"thinking":true,"reasoning_effort":"low"}''
        "--generation-config"
        "vllm"
        "--enable-flashinfer-autotune"
      ];
    };

    endpoint = {
      inherit port;
      startupTimeoutSeconds = 3600;
    };
  };
}
