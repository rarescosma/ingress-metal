#!/usr/bin/env bash

DOT=$(cd -P "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
IMAGE="${IMAGE:-registry.k8s.io/ingress-nginx/controller:v1.10.1}"
DOCKER="${DOCKER:-docker}"
IN_DOCKER="${IN_DOCKER:-0}"

LUA_SHARE="/usr/local/share/lua/5.1"
LUA_LIB="/usr/local/lib/lua/5.1"

check_deps() {
    _deps=(
        "openssl"
        "${DOCKER}"
        "dpkg-deb"
    )
    for _dep in "${_deps[@]}"; do
        if ! command -v "$_dep" >/dev/null; then
            echo -e "couldn't find $_dep; aborting"
            exit 1
        fi
    done
}

main() {
    check_deps
    docker_exodus
    copy_extras
    make_deb
    ${DOCKER} rm -f $c_name
}

detach() {
    sleep infinity
}

docker_exodus() {
    c_name="ingress-$(openssl rand -hex 12)"
    ${DOCKER} run -d --rm --name $c_name --entrypoint="/bin/bash" \
        -v ${DOT}/build.sh:/build.sh -v ${DOT}/exodus:/exodus \
        --user root \
        ${IMAGE} /build.sh detach
    ${DOCKER} exec -it $c_name /build.sh do_exodus
}

do_exodus() {
    set -ex
    # install exodus
    apk update
    apk add --no-cache python3
    rm /usr/lib/python3.11/EXTERNALLY-MANAGED
    python3 -m ensurepip
    pip3 install exodus-bundler

    # port the nginx-ingress-controller + nginx binaries
    exodus -o /exodus/controller-setup /nginx-ingress-controller
    exodus -o /exodus/nginx-setup nginx

    # lua things
    mkdir -p "${LUA_SHARE}"
    mv /usr/local/lib/lua/ngx "${LUA_SHARE}"/
    mv /usr/local/lib/lua/resty "${LUA_SHARE}"/
    mv /usr/local/lib/lua/librestychash.so "${LUA_LIB}"/
}

make_deb() {
    _opt="${DOT}/pkgroot/opt/ingress-metal"

    ${DOT}/exodus/controller-setup "$_opt"
    ${DOT}/exodus/nginx-setup "$_opt"
    cp -f ${DOT}/bin/run.sh "$_opt/bin/"
    cp -f ${DOT}/bin/is-up.sh "$_opt/bin/"

    dpkg-deb --build --root-owner-group pkgroot ingress-metal.deb
}

copy_extras() {
    _extras=(
        "/etc/nginx"
        "${LUA_SHARE}"
        "${LUA_LIB}/cjson.so"
        "${LUA_LIB}/librestychash.so"
        "/usr/lib/libbrotlicommon.so.1"
        "/usr/lib/libbrotlidec.so.1"
        "/usr/lib/libbrotlienc.so.1"
    )
    for _extra in "${_extras[@]}"; do
        _to="${DOT}/pkgroot$(dirname $_extra)/"
        mkdir -p $_to
        if [[ "${IN_DOCKER}" == "0" ]]; then
          ${DOCKER} cp -L $c_name:$_extra $_to
        else
          cp -r -L $_extra $_to
        fi
    done
}

cleanup() {
    ${DOCKER} ps -a | grep "ingress-" | cut -d" " -f1 | xargs ${DOCKER} rm -f
    rm -rf ${DOT}/pkgroot/{usr/{local/{lib,share},lib},etc/nginx,opt} ${DOT}/*.deb
}

if test -z "$1"; then
    main
else
    "$1"
fi

