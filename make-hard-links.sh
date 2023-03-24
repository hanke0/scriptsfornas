#!/usr/bin/env bash

usage="
Usage: ${0##*/} [OPTION]... [files]... dest_directory
Extend ln support directory.

OPTION:
    -j --junk-path              junk paths (do not make directories)
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"

require_basic_commands
require_command ln mkdir dirname

if [ "${#PARAMS[@]}" -lt 2 ]; then
    ${0} -h
    exit 1
fi

dest="${PARAMS[${#PARAMS[@]} - 1]}"

if [ ! -e "$dest" ]; then
    mkdir -p "$dest"
fi

if [ ! -d "$dest" ]; then
    echo >&2 "destination is not a folder: $dest"
    exit 1
fi

lnfile() {
    ln --interactive --logical --physical --no-target-directory "$@"
}

do_link_folder() {
    local target="$1"
    local linkfolder="$2"
    mkdir -p "$linkfolder"
    local f base
    while IFS= read -r -d '' -u 5 f; do
        base="$(basename "$f")"
        if [ -d "$f" ]; then
            do_link_folder "$f" "$linkfolder/$base"
            continue
        fi
        if [ -f "$f" ]; then
            lnfile "$f" "$linkfolder/$base"
        fi
    done 5< <(find "$target" -mindepth 1 -maxdepth 1 -not -path '*/.*' -print0)
}

for file in "${PARAMS[@]:0:${#PARAMS[@]}-1}"; do
    filename="$(basename "$file")"
    if [ -d "$file" ]; then
        do_link_folder "$file" "$dest"
        continue
    fi
    lnfile "$file" "$dest/$filename"
done
