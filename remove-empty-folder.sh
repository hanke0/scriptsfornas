#!/usr/bin/env bash

set -e

usage="
Usage: ${0##*/} [OPTION]... [FOLDER]
Remove all folder contains no data.

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

remove_empty_folder() {
    if [ -z "$(ls -A "$1")" ]; then
        echo "FIND: $1"
        mkdir -p "$TRASH/$1"
        mv "$1" "$TRASH/$1"
    fi
}

find "$FOLDER" -type d -print0 | while IFS= read -r -d '' fold; do
    [[ "$fold" =~ ^"$TRASH" ]] && continue
    remove_empty_folder "$fold"
done
