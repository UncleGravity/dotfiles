# Serve models

## DeepSeek V4 Flash 0731

The `deepseek-v4-flash-0731` recipe adapts the upstream two-DGX-Spark DSpark
configuration to the static cluster services. It pins the official model at
commit `7872f01b1d1fe23eabc4c98b48bffcef5a386062` and the Anemll GB10 vLLM image
at its exact OCI digest. It declares worker-first startup, while its
recipe-local entrypoint installs the checkpoint's encoding module and derives
rank and rendezvous arguments from the generated plan. The service uses TP=2
with NCCL traffic balanced across the `mlx5_0` and `mlx5_2` RoCE devices;
rendezvous and other control traffic remain on `fabric0`. It also uses NVFP4
DS-MLA KV cache, DSpark speculative decoding, regular CUDA graphs, and a
524,288-token context ceiling. The distributed startup timeout is extended to
cover graph capture on both ranks.

Archive the approximately 167 GB checkpoint once. This command is resumable:

```bash
ssh spark-01.local models archive \
  deepseek-ai/DeepSeek-V4-Flash-0731@7872f01b1d1fe23eabc4c98b48bffcef5a386062
```

Stop Laguna before allocating both nodes, then start and follow the control
unit:

```bash
ssh spark-01.local sudo systemctl stop infer-laguna
ssh spark-01.local sudo systemctl start infer-deepseek-v4-flash-0731
ssh spark-01.local journalctl -fu infer-deepseek-v4-flash-0731
```

The controller stages the model on `spark-01`, copies the verified artifact to
`spark-02` over `fabric0`, publishes one image digest, starts the worker first,
and reports ready only after the head API is healthy. The OpenAI-compatible API
is then available at `http://192.168.1.31:8888/v1` with served model name
`spark-current`.

```bash
ssh spark-01.local curl --fail http://192.168.1.31:8888/v1/models
ssh spark-01.local sudo systemctl stop infer-deepseek-v4-flash-0731
```

The instance remains `autoStart = false` because it allocates both Sparks and
has a substantial cold-start cost. Triton, B12x, FlashInfer, and vLLM compiler
caches persist below `/var/cache/deepseek-v4-flash-0731`; KV cache and
max-context workspaces are recreated on every process start.

## Laguna S 2.1 with vLLM

The `laguna-vllm` recipe pins CUDA 13, vLLM, FlashInfer, both model revisions,
and the complete container invocation. Nix installs `infer-laguna.service` on
`spark-01` but leaves it stopped by default.

Archive both models once from the controller. Repeating either command is safe:

```bash
ssh spark-01.local models archive \
  poolside/Laguna-S-2.1-NVFP4@b482b5d57fda6e4e562a652869bde24ba2a57c92

ssh spark-01.local models archive \
  poolside/Laguna-S-2.1-DFlash-NVFP4@723794750422b3efbf3a7b3af76dffb4ba035943
```

Start the service and follow its complete preparation and runtime log:

```bash
ssh spark-01.local sudo systemctl start infer-laguna
ssh spark-01.local journalctl -fu infer-laguna
```

The first start stages both archived models to local NVMe, builds and publishes
the image when its build hash is absent, restores its exact digest, and waits
for the vLLM health endpoint. The preserved `/var/cache/vllm-laguna` mount
retains runtime compilation artifacts across container restarts. The recipe
selects vLLM's `fastsafetensors` loader; on `spark-01` this reduced the reported
weight-loading phase from 472.53 seconds to about 21 seconds. The instance
remains `autoStart = false` so the Spark is allocated explicitly.

## Open WebUI

Open WebUI uses the controller's vLLM endpoint as its only model provider. It
binds to loopback during initial setup so another LAN client cannot claim the
first account, which Open WebUI promotes to administrator.

Enable the `open-webui.nix` import in `inference/default.nix`, deploy
`spark-01`, then keep this tunnel running while using the UI:

```bash
ssh -N -L 8080:127.0.0.1:8080 spark-01.local
```

Open <http://127.0.0.1:8080>, create the administrator account, and disable new
account registration. Application data persists in `/var/lib/open-webui`;
model weights remain in `/srv/models` and are served through vLLM.
