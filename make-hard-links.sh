#!/usr/bin/env bash

usage="
Usage: ${0##*/} [OPTION]... [files]... dest_directory
Make windows hard links files using wsl.

OPTION:
    
"

. "/home/kehan/codes/scriptsfornas/base-for-all.sh"

getopt_from_usage "$usage" "$@"

if [ "${#PARAMS[@]}" -lt 2 ]; then
    ${0} -h
    exit 1
fi

dest="${PARAMS[${#PARAMS[@]} - 1]}"

if [ ! -d "$dest" ]; then
    echo >&2 "destination is not a folder: $dest"
    exit 1
fi

do_link_folder() {
    local target="$1"
    local linkfolder="$2"
    mkdir -p "$linkfolder"
    local f base
    for f in "$target"/*; do
        base="$(basename "$f")"
        if [ -d "$f" ]; then
            do_link_folder "$f" "$linkfolder/$base"
            continue
        fi
        if [ -f "$f" ]; then
            ln -i "$f" "$linkfilder/$base"
        fi
    done
}

for file in "${PARAMS[@]:0:${#PARAMS[@]}-1}"; do
    filename="$(basename "$file")"
    if [ -d "$file" ]; then
        do_link_folder "$file" "$dest"
        continue
    fi
    ln -i "$file" "$dest/$filename"
done
