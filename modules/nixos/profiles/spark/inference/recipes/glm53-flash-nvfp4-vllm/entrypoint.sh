#!/usr/bin/env bash
set -euo pipefail

: "${INFER_HEAD_ADDRESS:?missing INFER_HEAD_ADDRESS}"
: "${INFER_NODE_ADDRESS:?missing INFER_NODE_ADDRESS}"
: "${INFER_RANK:?missing INFER_RANK}"
: "${INFER_ROLE:?missing INFER_ROLE}"
: "${INFER_WORLD_SIZE:?missing INFER_WORLD_SIZE}"

case "${INFER_WORLD_SIZE}" in
2 | 4) ;;
*)
  echo "GLM 5.3 Flash NVFP4 requires two or four nodes" >&2
  exit 2
  ;;
esac

case "${INFER_ROLE}" in
head | worker) ;;
*)
  echo "unsupported inference role: ${INFER_ROLE}" >&2
  exit 2
  ;;
esac

export VLLM_HOST_IP="${INFER_NODE_ADDRESS}"

cluster_args=(
  --tensor-parallel-size "${INFER_WORLD_SIZE}"
  --nnodes "${INFER_WORLD_SIZE}"
  --node-rank "${INFER_RANK}"
  --master-addr "${INFER_HEAD_ADDRESS}"
  --master-port 25000
)

if [[ ${INFER_ROLE} == "worker" ]]; then
  cluster_args+=(--headless)
fi

exec vllm serve "$@" "${cluster_args[@]}"
