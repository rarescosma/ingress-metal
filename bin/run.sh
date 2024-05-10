#!/usr/bin/env bash

DOT=$(cd -P "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
KC="${1}"
NS="${NS:-ingress-system}"
CONFIG_MAP="${CONFIG_MAP:-ingress-metal}"

if ! test -f "$(readlink -f "${KC}")"; then
  echo -e "pass me the path to a kubeconfig"
  exit 1
fi

mkdir -p /var/log/nginx /tmp/nginx

set -e

export POD_NAMESPACE="$NS"
export POD_NAME=$(\
    kubectl --kubeconfig="${KC}" get pods -n "${NS}" \
    -l app.kubernetes.io/sys=ingress-nginx \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}')

exec ${DOT}/nginx-ingress-controller --http-port=80 --https-port=443 \
    --kubeconfig "${KC}" --enable-metrics=false \
    --election-id=ingress-metal \
    --configmap=${POD_NAMESPACE}/${CONFIG_MAP}
