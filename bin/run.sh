#!/usr/bin/env bash

DOT=$(cd -P "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
KC="${1}"
NS="${NS:-ingress-system}"
CONFIG_MAP="${CONFIG_MAP:-ingress-metal}"
IFACE="${IFACE:-eth0}"

if ! test -f "$(readlink -f "${KC}")"; then
  echo -e "pass me the path to a kubeconfig"
fi

cleanup() {
  local bundle_id
  bundle_id="$(readlink -f "${DOT}/nginx" | awk -F'/bundles/' '{$0=$2}1' | cut -d"/" -f1)"
  sudo pkill -f "${bundle_id}"
  sudo iptables-save | grep "ni-block-" | sed -r 's/-A/sudo iptables -D/ge'
}

set -e
trap cleanup TERM INT QUIT EXIT

sudo mkdir -p /var/log/nginx /tmp/nginx

export POD_NAMESPACE="$NS"
export POD_NAME=$(\
    kubectl --kubeconfig="${KC}" get pods -n "${NS}" \
    -l app.kubernetes.io/sys=ingress-nginx \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}')

RULES="$(sudo iptables-save)"
(echo "$RULES" | grep 'ni-block-10254') || sudo iptables -A INPUT -i ${IFACE} -p tcp \
    --dport 10254 -m comment --comment 'ni-block-10254' -j DROP
(echo "$RULES" | grep 'ni-block-8181') || sudo iptables -A INPUT -i ${IFACE} -p tcp \
    --dport 8181 -m comment --comment 'ni-block-8181' -j DROP

sudo -E ${DOT}/nginx-ingress-controller --http-port=80 --https-port=443 \
    --kubeconfig "${KC}" --enable-metrics=false \
    --election-id=ingress-metal \
    --configmap=${POD_NAMESPACE}/${CONFIG_MAP}
