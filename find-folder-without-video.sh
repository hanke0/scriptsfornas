#!/usr/bin/env bash

set -e

usage="
Usage: ${0##*/} [OPTION]... [FOLDER]
Find all folder contains no vidoe files.
If NO folder input, default to working directory.

OPTION:
  -d --depth=DEPTH      depth of folder(default to 1).
"

. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands

if [ -z "$DEPTH" ]; then
    DEPTH=1
fi

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
    find "$1" -type f -print0 | while IFS= read -r -d '' file; do
        if is_video_file "$file"; then
            return 1
        fi
    done
}

find_folder_without_video() {
    if no_video_or_folder "$1"; then
        echo "$1"
    fi
}

find "$FOLDER" -maxdepth "$DEPTH" -type d -print0 | while IFS= read -r -d '' fold; do
    find_folder_without_video "$fold"
done
