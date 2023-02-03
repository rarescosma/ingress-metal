#!/usr/bin/env bash

DOT=$(cd -P "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
IMAGE="${IMAGE:-registry.k8s.io/ingress-nginx/controller:v1.5.1}"

LUA_SHARE="/usr/local/share/lua/5.1"
LUA_LIB="/usr/local/lib/lua/5.1"

main() {
    _deps=(
        "openssl"
        "docker"
        "dpkg-deb"
    )
    for _dep in "${_deps[@]}"; do
        if ! command -v "$_dep" >/dev/null; then
            echo -e "couldn't find $_dep; aborting"
            exit 1
        fi
    done

    c_name="ingress-$(openssl rand -hex 12)"
    docker run -d --rm --name $c_name --entrypoint="/bin/bash" \
        -v ${DOT}/build.sh:/build.sh -v ${DOT}/exodus:/exodus \
        --user root \
    docker exec -it $c_name /build.sh do_exodus
        ${IMAGE} /build.sh detach

    _extras=(
        "/etc/nginx"
        "${LUA_SHARE}"
        "${LUA_LIB}/cjson.so"
        "${LUA_LIB}/librestychash.so"
    )
    for _extra in "${_extras[@]}"; do
        _to="${DOT}/pkgroot$(dirname $_extra)/"
        mkdir -p $_to
        docker cp $c_name:$_extra $_to
    done

    _opt="${DOT}/pkgroot/opt/ingress-metal"

    ${DOT}/exodus/controller-setup "$_opt"
    ${DOT}/exodus/nginx-setup "$_opt"
    cp -f ${DOT}/bin/run.sh "$_opt/bin/"
    cp -f ${DOT}/bin/is-up.sh "$_opt/bin/"

    dpkg-deb --build --root-owner-group pkgroot ingress-metal.deb
    docker rm -f -t0 $c_name
}

detach() {
    sleep 3600
}

do_exodus() {
    set -ex
    # install exodus
    apk update
    apk add --no-cache python3
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

cleanup() {
    docker ps -a | grep "ingress-" | cut -d" " -f1 | xargs docker rm -f -t0
    rm -rf ${DOT}/pkgroot/{usr/local/lib,etc,opt} ${DOT}/*.deb
}

if test -z "$1"; then
    main
else
    "$1"
fi

