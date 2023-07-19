#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... [folder]...
Rename videos folder by nfo.

OPTION:
    -y, --yes                    do not ask.
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
# require_command

XMLQUERY="$(dirname "$(realpath "$0")")/xmlquery.sh"

isvideo() {
    if [ -f "$1/tvshow.nfo" ]; then
        return true
    fi
}

getname() {
    local dest title originaltitle
    title="$1"
    originaltitle="$2"
    if [ "$title" = "$originaltitle" ]; then
        dest="$title"
    else
        dest="$title.$originaltitle"
    fi
    dest="${dest//[^[:alnum:]]/.}"
    # shellcheck disable=SC2001
    sed 's/\.\.\.*/./g' <<<"$dest"
}

movefolder() {
    local src destname
    src="$1"
    destname="$2"
    if [ "$(basename "$src")" = "$destname" ]; then
        return 0
    fi
    dest="$(dirname "$src")/$destname"
    jobprompt="mv '$src' '$destname'"
    if istrue "$YES"; then
        mv "$1" "$dest"
        echo "$jobprompt"
        return 0
    fi
    if ask_yes "${jobprompt}?[Y/n]" yes; then
        mv "$1" "$dest"
    else
        echo "abort"
    fi
}

isinteger() {
    case "$1" in
    [0-9]+)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

goodfields() {
    local file title originaltitle year
    file="$1"
    title="$2"
    originaltitle="$3"
    year="$4"
    if [ -z "$title" ]; then
        echo >&2 "can not get title from $file"
        return 1
    fi
    if [ -z "$originaltitle" ]; then
        echo >&2 "can not get originaltitle from $file"
        return 1
    fi
    if ! isinteger "$year"; then
        echo >&2 "can not get year from $file"
        return 1
    fi
    return 0
}

domovie() {
    local file title originaltitle year fullname jobprompt
    IFS= read -r -d '' file \
        < <(find "$1" -maxdepth 1 -mindepth 1 -type f -name '*.nfo' -print0) ||
        true
    if [ -z "$file" ]; then
        echo >&2 "can not find nfo file: $1"
        return 0
    fi

    title="$("$XMLQUERY" 'movie.title' "$file")"
    originaltitle="$("$XMLQUERY" 'movie.originaltitle' "$file")"
    year="$("$XMLQUERY" 'movie.year' "$file")"

    if ! goodfields "$file" "$title" "$originaltitle" "$year"; then
        return 0
    fi
    fullname="$(getname "$title" "$originaltitle")"
    movefolder "$1" "$fullname.$year"
}

dotv() {
    local src file title originaltitle year fullname jobprompt seasonnfo
    if [ ! -f "$file" ]; then
        echo >&2 "can not find nfo file: $1"
        return 0
    fi
    src="$(dirname "$1")"

    title="$("$XMLQUERY" 'tvshow.title' "$file")"
    originaltitle="$("$XMLQUERY" 'tvshow.originaltitle' "$file")"
    year="$("$XMLQUERY" 'tvshow.year' "$file")"

    if ! goodfields "$file" "$title" "$originaltitle" "$year"; then
        return 0
    fi
    fullname="$(getname "$title" "$originaltitle")"

    while IFS= read -r -d '' seasonnfo; do
        dotvseason "$fullname" "$seasonnfo"
    done < <(find "$src" -mindepth 2 -maxdepth 2 -name "season.nfo")

    movefolder "$src" "$fullname.$year"
}

dotvseason() {
    local fullname nfo src dest season
    fullname="$1"
    nfo="$2"

    src="$(dirname "$nfo")"
    season="$("$XMLQUERY" 'season.seasonnumber' "$nfo")"
    if ! isinteger "$season"; then
        echo >&2 "cannot get season from $nfo"
        return 0
    fi
    movefolder "$src" "$fullname.$(printf '%02d' "$season")"
}

doone() {
    local file

    file="$1/tvshow.nfo"
    if [ -f "$file" ]; then
        dotv "$file"
        return
    fi
    domovie "$1"
}

for folder in "${PARAMS[@]}"; do
    doone "$folder"
done
