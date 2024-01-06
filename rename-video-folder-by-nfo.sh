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

getname() {
    local dest title originaltitle
    title="$1"
    originaltitle="$2"
    if [ "$title" = "$originaltitle" ]; then
        dest="$title"
    else
        dest="$title.$originaltitle"
    fi
    cleanname "$dest"
}

cleanname() {
    local dest
    dest="$1"
    dest="${dest//[^[:alnum:]]/.}"
    # shellcheck disable=SC2001
    sed 's/\.\.\.*/./g' <<<"$dest"
}

movefolder() {
    local src dest
    src="$1"
    dest="$(dirname "$src")/$2"
    if samedir "$src" "$dest"; then
        return 0
    fi

    jobprompt="mv -- '$src' '$dest'"
    if istrue "$YES"; then
        mv -- "$1" "$dest"
        echo "$jobprompt"
        return 0
    fi
    if ask_yes "${jobprompt}?[Y/n]" yes; then
        mv -- "$1" "$dest"
    else
        echo "abort"
    fi
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
    if ! [ "$year" -gt 0 ]; then
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
    movefolder "$1" "$(cleanname "$fullname.$year")"
}

dotvseason() {
    local fullname nfo src dest season
    fullname="$1"
    nfo="$2"

    src="$(dirname "$nfo")"
    season="$("$XMLQUERY" 'season.seasonnumber' "$nfo")"
    if ! [ "$season" -gt 0 ]; then
        echo >&2 "cannot get season from $nfo"
        return 0
    fi
    movefolder "$src" "$(cleanname "$fullname.S$(printf '%02d' "$season")")"
}

dotv() {
    local src file title originaltitle year fullname jobprompt seasonnfo
    file="$1"
    if ! [ -f "$file" ]; then
        echo >&2 "can not find nfo file: $file"
        return 0
    fi
    src="$(dirname "$file")"

    title="$("$XMLQUERY" 'tvshow.title' "$file")"
    originaltitle="$("$XMLQUERY" 'tvshow.originaltitle' "$file")"
    year="$("$XMLQUERY" 'tvshow.year' "$file")"

    if ! goodfields "$file" "$title" "$originaltitle" "$year"; then
        return 0
    fi
    fullname="$(getname "$title" "$originaltitle")"

    while IFS= read -r -d '' -u5 seasonnfo; do
        dotvseason "$fullname" "$seasonnfo"
    done 5< <(find "$src" -mindepth 2 -maxdepth 2 -type f -name "season.nfo" -print0)

    movefolder "$src" "$(cleanname "$fullname.$year")"
}

doone() {
    local folder file
    folder="$(realpath "$1")"

    file="$folder/tvshow.nfo"
    if [ -f "$file" ]; then
        dotv "$file"
        return
    fi
    domovie "$1"
}

for folder in "${PARAMS[@]}"; do
    doone "$folder"
done
