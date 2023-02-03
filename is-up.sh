#!/usr/bin/env bash

DOT=$(cd -P "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)

bundle_id="$(readlink -f "${DOT}/nginx" | awk -F'/bundles/' '{$0=$2}1' | cut -d"/" -f1)"

exec pgrep -f "${bundle_id}" >/dev/null

