#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... <directory-contains-video> <target-directory>
Consolidate all videos into a single directory.

OPTION:
    -m, --mv            use mv instead of cp.
        --hardlink      use hardlink istead of cp.
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
# require_command

SRC="${PARAMS[0]}"
DST="${PARAMS[1]}"
if [ "${#PARAMS[@]}" -ne 2 ]; then
    echo >&2 "only source and target directory should provided"
    exit 1
fi
if [ ! -d "$SRC" ]; then
    echo >&2 "source folder is not exists"
    exit 1
fi
if [ -z "$DST" ]; then
    echo >&2 "destination folder name is empty"
    exit 1
fi

COLLECTCMD="cp"
if istrue "$MV"; then
    COLLECTCMD="mv"
fi
if istrue "$HARDLINK"; then
    COLLECTCMD="ln"
fi

do_video_callback() {
    "${COLLECTCMD}" "$(realpath "$1")" "$DST/$(basename "$1")"
}

find_videos_and_do_callback "$SRC" do_video_callback
