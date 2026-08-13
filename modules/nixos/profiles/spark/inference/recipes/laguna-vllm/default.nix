let
  targetModelRoot = "/models/target";
  draftModelRoot = "/models/draft";
  cachePath = "/var/cache/vllm-laguna";
  port = 8000;
  speculativeConfig = builtins.toJSON {
    model = draftModelRoot;
    num_speculative_tokens = 15;
    method = "dflash";
  };
in {
  systemd.tmpfiles.rules = [
    "d ${cachePath} 0755 root root -"
  ];

  my.inference.recipes.laguna-vllm = {
    models = {
      target = {
        repo = "poolside/Laguna-S-2.1-NVFP4";
        revision = "b482b5d57fda6e4e562a652869bde24ba2a57c92";
      };
      draft = {
        repo = "poolside/Laguna-S-2.1-DFlash-NVFP4";
        revision = "723794750422b3efbf3a7b3af76dffb4ba035943";
      };
    };

    image.context = ./.;

    container = {
      devices = ["nvidia.com/gpu=all"];
      extraOptions = ["--ipc=host"];
      environment = {
        CUDA_HOME = "/usr/local/cuda";
        CUTE_DSL_ARCH = "sm_121a";
        MAX_JOBS = "4";
        VLLM_NO_USAGE_STATS = "1";
      };
      mounts = [
        {
          sourcePath = cachePath;
          targetPath = "/root/.cache";
          readOnly = false;
        }
      ];
      args = [
        targetModelRoot
        "--load-format"
        "fastsafetensors" # Avoid slow mmap loading on GB10 unified memory.
        "--served-model-name"
        "poolside/Laguna-S-2.1-NVFP4"
        "--host"
        "0.0.0.0"
        "--port"
        (toString port)
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
        "262144"
        "--gpu-memory-utilization"
        "0.75"
      ];
    };

    endpoint = {
      inherit port;
      startupTimeoutSeconds = 1200;
    };
  };
}
