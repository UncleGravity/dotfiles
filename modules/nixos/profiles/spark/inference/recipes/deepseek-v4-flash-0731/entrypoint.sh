#!/usr/bin/env bash
set -euo pipefail

: "${INFER_HEAD_ADDRESS:?missing INFER_HEAD_ADDRESS}"
: "${INFER_NODE_ADDRESS:?missing INFER_NODE_ADDRESS}"
: "${INFER_RANK:?missing INFER_RANK}"
: "${INFER_ROLE:?missing INFER_ROLE}"
: "${INFER_WORLD_SIZE:?missing INFER_WORLD_SIZE}"

if [[ ${INFER_WORLD_SIZE} != "2" ]]; then
  echo "DeepSeek V4 Flash 0731 requires exactly two nodes" >&2
  exit 2
fi

case "${INFER_ROLE}" in
head | worker) ;;
*)
  echo "unsupported inference role: ${INFER_ROLE}" >&2
  exit 2
  ;;
esac

/usr/local/libexec/infer-deepseek-v4-prepare-runtime /models/model

export CUDA_HOME=/usr/local/cuda
export CUDA_PATH="${CUDA_HOME}"
export CUDAToolkit_ROOT="${CUDA_HOME}"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export PATH="/usr/local/cuda/bin:/usr/local/bin:${PATH}"
export VLLM_HOST_IP="${INFER_NODE_ADDRESS}"

cluster_args=(
  --nnodes "${INFER_WORLD_SIZE}"
  --node-rank "${INFER_RANK}"
  --master-addr "${INFER_HEAD_ADDRESS}"
  --master-port 25000
)

if [[ ${INFER_ROLE} == "worker" ]]; then
  cluster_args+=(--headless)
fi

exec /usr/local/bin/vllm serve "$@" "${cluster_args[@]}"
