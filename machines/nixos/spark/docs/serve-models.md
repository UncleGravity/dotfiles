# Serve models

## Laguna S 2.1 with vLLM

`spark-01` builds a pinned CUDA 13, vLLM, and FlashInfer container. The image
recipe is declarative, while model weights remain outside the Nix store.

Follow the image build:

```bash
ssh spark-01.local journalctl -fu vllm-laguna-image
```

Download the pinned target and DFlash draft revisions:

```bash
ssh spark-01.local hf download \
  poolside/Laguna-S-2.1-NVFP4 \
  --revision b482b5d57fda6e4e562a652869bde24ba2a57c92 \
  --local-dir /srv/models/poolside-Laguna-S-2.1-NVFP4

ssh spark-01.local hf download \
  poolside/Laguna-S-2.1-DFlash-NVFP4 \
  --revision 723794750422b3efbf3a7b3af76dffb4ba035943 \
  --local-dir /srv/models/poolside-Laguna-S-2.1-DFlash-NVFP4
```

Start the server manually for its first run:

```bash
ssh spark-01.local sudo systemctl start podman-vllm-laguna
ssh spark-01.local journalctl -fu podman-vllm-laguna
```

The first start can take about 15 minutes. After validation, set
`services.vllm-laguna.autoStart = true` in `inference/default.nix`.

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
