#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... <jq filter> [CONTAINER]...
Change container config base on jq.

OPTION:
    -d --directory=PATH   directory of docker container config (default to /var/lib/docker/containers)
    -i --inplce           inplace the original file.
    -H, --host=ADDRESS    docker daemon socket(s) to connect to
"

DIRECTORY=/var/lib/docker/containers
. "/home/kehan/codes/scriptsfornas/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands

do_docker() {
    if [ -z "${HOST}" ]; then
        docker --host "${HOST}" "$@"
    else
        docker "$@"
    fi 
}

FILTER="${PARAMS[0]}"
PARAMS=("${PARAMS[@]:1}")
if [ -z "${FILTER}" ]; then
    echo >&2 "jq filter must provided"
    exit 1
fi

change_one() {
    local name container config
    name="$1"
    container="$(do_docker inspect --format "{{.ID}}" "${name}")"
    config="${DIRECTORY}/${container}/config.v2.json"
    if [ ! -r "${config}" ]; then
        echo >&2 "bad container name ${name}"
        exit 1
    fi
    if [ -z "${INPLACE}" ]; then
        jq "${FILTER}" "${config}"
    else
        data="$(jq -c "${FILTER}" "${config}")"
        echo "$data" >"${config}"
    fi
}

for file in "${PARAMS[@]}"; do
    change_one "${file}"
done
