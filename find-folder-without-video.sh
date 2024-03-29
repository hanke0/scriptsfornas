#!/usr/bin/env bash

set -e

usage="
Usage: ${0##*/} [OPTION]... [FOLDER]
Find all folder contains no vidoe files.
If NO folder input, default to working directory.

OPTION:
  -d, --depth=DEPTH      depth of folder(default to 1).
      --nosub            videos in sub folder is ignored.
"

# shellcheck source=/dev/null
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

find_folder_without_video() {
    if [ -z "$(find_video_files "$1")" ]; then
        echo "$1"
    fi
}

find "$FOLDER" -maxdepth "$DEPTH" -mindepth "$DEPTH" -type d -print0 | while IFS= read -r -d '' fold; do
    find_folder_without_video "$fold"
done
