#!/usr/bin/env bash
set -euo pipefail

: "${INFER_HEAD_ADDRESS:?missing INFER_HEAD_ADDRESS}"
: "${INFER_NODE_ADDRESS:?missing INFER_NODE_ADDRESS}"
: "${INFER_RANK:?missing INFER_RANK}"
: "${INFER_ROLE:?missing INFER_ROLE}"
: "${INFER_WORLD_SIZE:?missing INFER_WORLD_SIZE}"

if [[ ${INFER_WORLD_SIZE} != "4" ]]; then
  echo "GLM 5.2 TP4/DCP4 requires exactly four nodes" >&2
  exit 2
fi

case "${INFER_ROLE}" in
head | worker) ;;
*)
  echo "unsupported inference role: ${INFER_ROLE}" >&2
  exit 2
  ;;
esac

readonly ray_port=26479
readonly object_store_bytes=134217728
readonly model_root=/cache/model
readonly ray_root="/cache/ray/${INFER_RANK}"

/usr/local/libexec/infer-glm52-prepare-model \
  /models/base \
  /models/mtp \
  "${model_root}"
mkdir -p "${ray_root}/spill" "${ray_root}/tmp"

export HOST_IP="${INFER_NODE_ADDRESS}"
export RAY_ADDRESS="${INFER_HEAD_ADDRESS}:${ray_port}"
export VLLM_HOST_IP="${INFER_NODE_ADDRESS}"

ray_common=(
  --node-ip-address="${INFER_NODE_ADDRESS}"
  --object-store-memory="${object_store_bytes}"
  --object-spilling-directory="${ray_root}/spill"
  --num-cpus=1
  --num-gpus=1
  --include-log-monitor=false
  --disable-usage-stats
  --temp-dir="${ray_root}/tmp"
)

if [[ ${INFER_ROLE} == "worker" ]]; then
  for ((attempt = 1; attempt <= 120; attempt++)); do
    if (: >/dev/tcp/"${INFER_HEAD_ADDRESS}"/"${ray_port}") 2>/dev/null; then
      exec ray start \
        --address="${INFER_HEAD_ADDRESS}:${ray_port}" \
        "${ray_common[@]}" \
        --block
    fi
    sleep 2
  done
  echo "Ray head did not become reachable at ${RAY_ADDRESS}" >&2
  exit 1
fi

ray start \
  --head \
  --port="${ray_port}" \
  --include-dashboard=false \
  "${ray_common[@]}"

cluster_ready=0
for ((attempt = 1; attempt <= 180; attempt++)); do
  if ray status --address="${RAY_ADDRESS}" 2>/dev/null | grep -q "/4.0 GPU"; then
    cluster_ready=1
    break
  fi
  sleep 2
done

if [[ ${cluster_ready} != "1" ]]; then
  ray status --address="${RAY_ADDRESS}" || true
  echo "Ray did not register all four Spark GPUs" >&2
  exit 1
fi

exec python3 -m vllm.entrypoints.openai.api_server "$@"
