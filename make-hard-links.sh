#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... [files]... DESTINATION_directory
Extend ln support directory.

OPTION:
    -j, --junk-path             link all files into a single directory.
    -d, --dir-mode              treat all source file as directory.
                                as result, src/*      -> dst/*
                                           src/path/* -> dst/path/*
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "${0}")")/base-for-all.sh"

getopt_from_usage "${usage}" "$@"

require_basic_commands
require_command ln mkdir dirname

if [ "${#PARAMS[@]}" -lt 2 ]; then
    ${0} -h
    exit 1
fi
DESTINATION="${PARAMS[${#PARAMS[@]} - 1]}"
if [ ! -e "$DESTINATION" ]; then
    mkdir -p "$DESTINATION"
fi
DESTINATION="$(realpath "$DESTINATION")"
if [ ! -d "$DESTINATION" ]; then
    echo >&2 "DESTINATIONination is not a folder: $DESTINATION"
    exit 1
fi

is_junk_path() {
    istrue "$JUNK_PATH"
}
is_dir_mode() {
    istrue "$DIR_MODE"
}

lnfile() {
    ln --interactive --logical --physical --no-target-directory "$@"
}

do_link_folder() {
    local target dst f base
    target="${1}"
    dst="${2}"
    mkdir -p "$dst"
    while IFS= read -r -d '' -u 5 f; do
        base="$(basename "$f")"
        if [ -d "$f" ]; then
            if is_junk_path; then
                do_link_folder "$f" "$dst"
            else
                do_link_folder "$f" "$dst/$base"
            fi
            continue
        fi
        if [ -f "$f" ]; then
            lnfile "$f" "$dst/$base"
        fi
    done 5< <(find "$target" -mindepth 1 -maxdepth 1 -not -path '*/.*' -print0)
}

for file in "${PARAMS[@]:0:${#PARAMS[@]}-1}"; do
    file="$(realpath "$file")"
    filename="$(basename "$file")"
    if [ -d "$file" ]; then
        if is_junk_path || is_dir_mode; then
            do_link_folder "$file" "$DESTINATION"
        else
            do_link_folder "$file" "$DESTINATION/$filename"
        fi
        continue
    fi
    lnfile "$file" "$DESTINATION/$filename"
done
