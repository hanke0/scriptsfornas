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
    IFS= read -r -d '' file \
        < <(find "$1" -maxdepth 1 -mindepth 1 -type f -name '*.nfo' -print0)

    if [ -z "$file" ]; then
        echo >&2 "can not find nfo file: $1"
        return 0
    fi
    title="$("$XMLQUERY" 'movie.title' "$file")"
    if [ -z "$title" ]; then
        title="$("$XMLQUERY" 'tvshow.title' "$file")"
    fi
    originaltitle="$("$XMLQUERY" 'movie.originaltitle' "$file")"
    if [ -z "$originaltitle" ]; then
        originaltitle="$("$XMLQUERY" 'tvshow.originaltitle' "$file")"
    fi
    year="$("$XMLQUERY" 'movie.year' "$file")"
    if [ -z "$year" ]; then
        year="$("$XMLQUERY" 'tvshow.year' "$file")"
    fi

    if [ -z "$title" ]; then
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

    if [ "$title" = "$originaltitle" ]; then
        dest="$title.$year"
    else
        dest="$title.$originaltitle.$year"
    fi
    dest="${dest//[^[:alnum:]]/.}"
    dest="$(sed 's/\.\.\.*/./g' <<<"$dest")"
    if [ "$(basename "$1")" = "$dest" ]; then
        return 0
    fi
    dest="$(dirname "$1")/$dest"
    if ask_yes "mv '$1' '$dest'?[Y/n]" yes; then
        mv "$1" "$dest"
    fi
}

for folder in "${PARAMS[@]}"; do
    doone "$folder"
done
