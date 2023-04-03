#!/usr/bin/env bash

set -e

usage="
Usage: ${0##*/} [OPTION]... [FOLDER]
Find all folder contains a video but nfo file is absent.

OPTION:
    -d, --directory         output video directory instead of video file path.
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

dovideo() {
    local path file
    file="$1"
    path="$(dirname "$file")"
    if [ -z "$(find "$path" -type f -iname "*.nfo")" ]; then
        if [ "$DIRECTORY" = 1 ]; then
            echo "$path"
        else
            echo "$file"
        fi
    fi
}

find_videos_and_do_callback "$FOLDER" dovideo
