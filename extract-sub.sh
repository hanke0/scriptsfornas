#!/usr/bin/env bash

set -e

usage="
Usage: ${0##*/} [OPTION]...
Deeply extract compressed files, that contains sub titles, into one folder.

OPTION:
    -d, --destination=PATH    extract into folder
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands

if [ -z "$DESTINATION" ]; then
    DESTINATION="./extracted"
fi

mkdir -p "$DESTINATION"
DESTINATION="$(realpath "$DESTINATION")"
if [ -n "$(ls "$DESTINATION")" ]; then
    echo >&2 "output folder contain files, try rm -rf $DESTINATION"
    exit 1
fi

extract() {
    case "$1" in
    *.rar)
        require_command unrar
        unrar e -y -c- -inul "$1" "$DESTINATION"
        ;;
    *.zip)
        unzip -j -qq -o -d "$DESTINATION" "$1"
        ;;
    *.tar.*)
        tar -xf --directory "$DESTINATION" "$1"
        ;;
    *.7z)
        7z e -y -bb3 "-o$DESTINATION" "$1"
        ;;
    *) ;;
    esac
}
FILES=()

for f in "${PARAMS[@]}"; do
    FILES+=("$(realpath "$f")")
done

cd "$DESTINATION"

for f in "${FILES[@]}"; do
    extract "$f"
done

find "$DESTINATION" \( -name "*.rar" -or -name "*.zip" -or -name "*.tar.*" -or -name "*.7z" \) -print0 |
    while IFS= read -r -d '' tar; do
        extract "$tar"
        rm "$tar"
    done

find "$DESTINATION" -type d -print0 |
    while IFS= read -r -d '' folder; do
        mv -f "$folder/"* "$DESTINATION/"
        rmdir "$folder"
    done
