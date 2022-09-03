#!/usr/bin/env bash

set -e

usage="
Usage: ${0##*/} [OPTION]... [FOLDER]
Remove all folder contains no vidoe files.
If NO folder input, default to working directory.

OPTION:
    -t --trash=PATH     set the trash folder. defult to [FOLDER]/deleted
"

. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"

FOLDER="${PARAMS[0]}"
if [ -z "$FOLDER" ]; then
    FOLDER="."
fi
FOLDER="$(realpath "$FOLDER")"

if [ ! -d "$FOLDER" ]; then
    echo >&2 "bad folder: ${PARAMS[0]}"
    exit 1
fi

if [ -z "$TRASH" ]; then
    TRASH="$FOLDER/deleted"
fi
if [ ! -e "$TRASH" ]; then
    mkdir -p "$TRASH"
fi
if [ ! -d "$TRASH" ]; then
    echo >&2 "bad trash folder: $TRASH"
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

remove_folder_without_video() {
    if no_video_or_folder "$1"; then
        echo "FIND: $1"
        mkdir -p "$TRASH/$1"
        mv "$1" "$TRASH/$1"
    fi
}

find "$FOLDER" -type d -print0 | while IFS= read -r -d '' fold; do
    [[ "$fold" =~ ^"$TRASH" ]] && continue
    remove_folder_without_video "$fold"
done
