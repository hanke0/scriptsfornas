#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]...
Test disk write speed.

OPTION:
    -t, --temp-file    temporary file name, if not set use 'mktemp -p .' generate a new one.
    -c, --chunk        write chunk size, in megabytes. (default to 1).
    -n, --count        write count, (default to 1000).
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
require_command dd time sync

if [ -z "$TEMP_FILE" ]; then
    TEMP_FILE=$(mktemp -p .)
else
    if [ -f "$TEMP_FILE" ]; then
        echo >&2 "$TEMP_FILE exists"
    fi
fi

if ! [[ "$COUNT" =~ [0-9]+ ]]; then
    COUNT=1000
fi

if ! [[ "$CHUNK" =~ [0-9]+ ]]; then
    CHUNK=1
fi

cleanup() {
    rm -f "$TEMP_FILE"
}

trap cleanup EXIT
CMD="sync; dd if=/dev/zero of=${TEMP_FILE}  bs=${CHUNK}M count=${COUNT}; sync"
echo "Execute: $CMD"
time -p bash -c "$CMD"
