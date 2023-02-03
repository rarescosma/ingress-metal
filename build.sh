#!/usr/bin/env bash

DOT=$(cd -P "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)

main() {
    _deps=(
        "openssl"
        "docker"
        "dpkg-deb"
    )
    for _dep in "${_deps[@]}"; do
        if ! command -v "$_dep"; then
            echo -e "couln't find $_dep; aborting"
            exit 1
        fi
    done

    upstream=hub.getbetter.ro/ingress-nginx-controller:v1.5.2
    c_name="ingress-$(openssl rand -hex 12)"
    #c_name="ingress-ab8acda870a7eec6d8c144e1"
    echo $c_name
    docker run -d --rm --name $c_name --entrypoint="/bin/bash" -v ${DOT}/build.sh:/build.sh -v ${DOT}/exodus:/exodus --user root $upstream /build.sh detach
    docker exec -it $c_name /build.sh do_exodus

    _extras=(
        "/etc/nginx"
        "/usr/local/share/lua/5.1"
        "/usr/local/lib/lua/5.1/cjson.so"
        "/usr/local/lib/lua/5.1/librestychash.so"
    )
    for _extra in "${_extras[@]}"; do
        _to="${DOT}/pkgroot$(dirname $_extra)/"
        mkdir -p $_to
        docker cp $c_name:$_extra $_to
    done

    _opt="${DOT}/pkgroot/opt/ingress-metal"

    ${DOT}/exodus/controller-setup "$_opt"
    ${DOT}/exodus/nginx-setup "$_opt"
    cp -f ${DOT}/run.sh "$_opt/bin/"

    dpkg-deb --build --root-owner-group pkgroot ingress-metal.deb
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
    mkdir -p /usr/local/share/lua/5.1
    mv /usr/local/lib/lua/ngx /usr/local/share/lua/5.1/
    mv /usr/local/lib/lua/resty /usr/local/share/lua/5.1/
    mv /usr/local/lib/lua/librestychash.so /usr/local/lib/lua/5.1/
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

