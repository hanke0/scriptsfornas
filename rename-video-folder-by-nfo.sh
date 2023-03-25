#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... [folder]...
Rename videos folder by nfo.

OPTION:

"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
# require_command

XMLQUERY="$(dirname "$(realpath "$0")")/xmlquery.sh"

doone() {
    local file title originaltitle year dest
    while IFS= read -r -d '' -u 5 file; do
        :
    done 5< <(find "$1" -maxdepth 1 -mindepth 1 -type f -name '*.nfo' -print0)

    if [ -z "$file" ]; then
        echo >&2 "can not find nfo file: $1"
        return 0
    fi
    title="$("$XMLQUERY" 'movie.title' "$file")"
    if [ -z "$tile" ]; then
        title="$("$XMLQUERY" 'tvshow.title' "$file")"
    fi
    originaltitle="$("$XMLQUERY" 'movie.originaltitle' "$file")"
    if [ -z "$tile" ]; then
        originaltitle="$("$XMLQUERY" 'tvshow.originaltitle' "$file")"
    fi
    year="$("$XMLQUERY" 'movie.year' "$file")"
    if [ -z "$tile" ]; then
        originaltitle="$("$XMLQUERY" 'tvshow.year' "$file")"
    fi

    if [ -z "$tile" ]; then
        echo >&2 "can not get title from $file"
        return 0
    fi
    if [ -z "$originaltitle" ]; then
        echo >&2 "can not get originaltitle from $file"
        return 0
    fi
    if [ -z "$year" ]; then
        echo >&2 "can not get year from $file"
        return 0
    fi

    if [ "$tile" = "$originaltitle" ]; then
        dest="$tile.$year"
    else
        dest="$tile.$originaltitle.$year"
    fi
    dest="${dest// /.}"

    if ask_yes "mv '$1' '$dest'?[Y/n]" yes; then
        mv "$1" "$dest"
    fi
}

for folder in "${PARAMS[@]}"; do
    doone "$folder"
done
