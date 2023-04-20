#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... [folder]...
Move movie folder by actor.
Must a jellyfin movie folder.

OPTION:
    -y, --yes                    do not ask.
    -d, --destination=FOLDER     destination folder (default to .).
    -m, --multi-to=STRING        multi actor move to (default to others)
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

DESTINATION=.
getopt_from_usage "$usage" "$@"
require_basic_commands
# require_command

XMLQUERY="$(dirname "$(realpath "$0")")/xmlquery.sh"

doone() {
    local file actor num
    file=
    IFS= read -r -d '' file \
        < <(find "$1" -maxdepth 1 -mindepth 1 -type f -name '*.nfo' -print0)

    if [ -z "$file" ]; then
        echo >&2 "can not find nfo file: $1"
        return 0
    fi
    actor="$("$XMLQUERY" '*actor.name' "$file")"
    if [ -z "$actor" ]; then
        echo >&2 "can not get actor from $file"
        return 0
    fi
    num="$(wc -l <<<"$actor")"

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
    # shellcheck disable=SC2001
    dest="$(sed 's/\.\.\.*/./g' <<<"$dest")"
    if [ "$(basename "$1")" = "$dest" ]; then
        return 0
    fi
    dest="$(dirname "$1")/$dest"
    jobprompt="mv '$1' '$dest'"
    if istrue "$YES"; then
        mv "$1" "$dest"
        echo "$jobprompt"
        return 0
    fi
    if ask_yes "${jobprompt}?[Y/n]" yes; then
        mv "$1" "$dest"
    fi
}

for folder in "${PARAMS[@]}"; do
    doone "$folder"
done
