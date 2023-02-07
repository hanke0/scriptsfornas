#!/usr/bin/env bash

set -e

usage="
Usage: ${0##*/} [OPTION]... [FOLDER]
Find all folder contains no vidoe files.
If NO folder input, default to working directory.

OPTION:
"

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

no_video_or_folder() {
    for f in "$1"/*; do
        [ ! -f "$f" ] && return 1
        if is_video_file "$f"; then
            return 1
        fi
    done
    return 0
}

find_folder_without_video() {
    if no_video_or_folder "$1"; then
        echo "$1"
    fi
}

find "$FOLDER" -type d -print0 | while IFS= read -r -d '' fold; do
    find_folder_without_video "$fold"
done
