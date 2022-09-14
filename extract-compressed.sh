#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]...
Deeply extract compressed files into one folder.

OPTION:
    -d, --destination=PATH    extract into folder
"

. "/home/kehan/codes/scriptsfornas/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands

if [ -z "$DESTINATION" ]; then
    DESTINATION="./extracted"
fi

mkdir -p "$DESTINATION"
DESTINATION="$(realpath "$DESTINATION")"

extract() {
    case "$1" in
    *.rar)
        require_command unrar
        unrar -x "$1"
        ;;
    *.zip)
        unzip -n -d "$DESTINATION" "$1"
        ;;
    *.tar.*)
        tar -xf --directory "$DESTINATION" "$1"
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

find "$DESTINATION" \( -name "*.rar" -or -name "*.zip" -or -name "*.tar.*" \) -print0 |
    while IFS= read -r -d '' tar; do
        extract "$tar"
    done
