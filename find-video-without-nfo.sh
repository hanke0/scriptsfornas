#!/usr/bin/env bash

set -e

usage="
Usage: ${0##*/} [OPTION]... [FOLDER]
Find all folder contains a video but nfo file is absent.

OPTION:
    -d, --directory         output video directory instead of video file path.
    -s, --samename          nfo file must have same name of video.
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands

FOLDER="${PARAMS[0]}"
if [ -z "$FOLDER" ]; then
    FOLDER="."
fi
FOLDER="$(realpath "$FOLDER")"

if [ ! -d "$FOLDER" ]; then
    echo >&2 "bad folder: ${PARAMS[0]}"
    exit 1
fi

hasnfo() {
    local path file
    path="$1"
    file="$2"
    if istrue "$SAMENAME"; then
        if [ -f "${file%.*}.nfo" ]; then
            return 0
        fi
        return 1
    fi
    [ -z "$(find "$path" -type f -iname "*.nfo")" ]
}

dovideo() {
    local path file
    file="$1"
    path="$(dirname "$file")"

    if ! hasnfo "$path" "$file"; then
        if [ "$DIRECTORY" = 1 ]; then
            echo "$path"
        else
            echo "$file"
        fi
    fi
}

find_videos_and_do_callback "$FOLDER" dovideo
