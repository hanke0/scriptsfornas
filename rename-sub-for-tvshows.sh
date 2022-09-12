#!/usr/bin/env bash

usage="
Usage: ${0##*/} [OPTION]... folder
Rename sub title files for TV shows.

OPTION:
       --mvoption=STRING         options for command mv
    -s --subfolder=DIRECTORY     folder to find sub
"

. "/home/kehan/codes/scriptsfornas/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands

find_eposide() {
    grep -i -o 'S[0-9][0-9]E[0-9][0-9]' < <(basename "$1")
}

find_sub_language() {
    grep -i -o -E '(ch|zh|en|简体|英文)[^\.]*\.[a-z]+$' < <(basename "$1") | sed -E 's/\..+$//g'
}

rename_an_eposide() {
    sublist=()
    local epfile="$1"
    local folder="$(dirname "$epfile")"
    local epbase="$(basename "$epfile")"
    local ep="$(find_eposide "$epfile")"
    local sub nsub subfoler
    if [ -z "$ep" ]; then
        return
    fi
    if [ -z "$SUBFOLDER" ]; then
        subfolder="$folder"
    else
        subfolder="$SUBFOLDER"
    fi
    find "$subfolder" \( -iname "*${ep}*.srt" -o -iname "*${ep}*.ass" \) -print0 |
        while IFS= read -r -d '' sub; do
            nsub="$(filename_base "$epfile").$(find_sub_language "$sub").$(filename_ext "$sub")"
            if [ "$nsub" != "$(basename "$sub")" ]; then
                mv $MVOPTION "$sub" "$folder/$nsub" </dev/tty
            fi
        done
}

rename_folder() {
    local f
    for f in "$1"/*; do
        if is_video_file "$f"; then
            rename_an_eposide "$f"
        fi
    done
}

for tv in "${PARAMS[@]}"; do
    if [ ! -d "$tv" ]; then
        echo >&2 "ignore not folder input: $tv"
        continue
    fi
    rename_folder "$tv"
done
