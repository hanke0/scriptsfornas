#!/usr/bin/env bash

set -e

videoext=(
    mkv mp4 avi rm rmbv mts m2ts ts webm flv vob ogv ogg drc mov qt wmv
    mepg mpg m2v m3v svi 3go f4v
)

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

is_video_ext() {
    local ext
    for ext in "${videoext[@]}"; do
        if [ "$ext" = "$1" ]; then
            return 0
        fi
    done
    return 1
}

no_video_or_folder() {
    local ext f
    for f in "$1"/*; do
        [ ! -f "$f" ] && return 1
        ext="${f##*.}"
        if is_video_ext "$ext"; then
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
