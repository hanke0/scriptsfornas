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
    -m, --multi-to=STRING        multi actor move to (default to multiactor)
        --dryrun                 dry run mode.
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

DESTINATION=.
MULTI_TO=multiactor
getopt_from_usage "$usage" "$@"
require_basic_commands
# require_command

XMLQUERY="$(dirname "$(realpath "$0")")/xmlquery.sh"

if istrue "$DRYRUN"; then
    x() {
        :
    }
else
    x() {
        "$@" "$@"
    }
fi

doone() {
    local file actor num dest
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
    if [ "$num" -gt 1 ]; then
        dest="$DESTINATION/$MULTI_TO/"
    else
        dest="$DESTINATION/${actor//[[:blank:]]/}/"
    fi
    x mkdir -p "$dest"
    jobprompt="mv '$1' '$dest'"
    if istrue "$YES"; then
        x mv "$1" "$dest"
        echo "$jobprompt"
        return 0
    fi
    if ask_yes "${jobprompt}?[Y/n]" yes; then
        x mv "$1" "$dest"
    else
        echo >&2 "user abort"
    fi
}

for folder in "${PARAMS[@]}"; do
    if [ -d "$folder" ]; then
        file=
        while IFS= read -r -d '' -u 5 file; do
            doone "$(dirname "$file")"
        done 5< <(find "$folder" -type f -name '*.nfo' -print0)
    else
        echo >&2 "not a folder or foler not exist: $folder"
    fi
done
