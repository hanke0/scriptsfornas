#!/usr/bin/env bash

set -e

usage="
Usage: ${0##*/} [OPTION]... [FILE]...
Convert file encoding into UTF-8 and changes CRLF to LF.

OPTION:
    -s, --suffix=SUFFIX      suffix of output file, set empty to replace file.(default to replace original file)
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"

if ! option_has_set "SUFFIX"; then
    SUFFIX=""
fi

require_basic_commands
require_command iconv dos2unix dirname

chardet() {
    if ! uchardet "$1"; then
        exit 1
    fi
}

for f in "${PARAMS[@]}"; do
    if [ ! -f "$f" ]; then
        continue
    fi
    chardet="$(chardet "$f")"
    if [ "$chardet" = "UTF-8" ]; then
        continue
    fi
    ext="$(filename_ext "$f")"
    base="$(filename_base "$f")$SUFFIX"
    if [ -z "$ext" ]; then
        name="$(dirname "$f")/$base"
    else
        name="$(dirname "$f")/$base.$ext"
    fi
    tmp="$name.$RANDOM"
    if ! iconv -f "$chardet" -t "UTF-8" -o "$tmp" "$f"; then
        rm "$tmp"
        echo >&2 "convert fail: $f"
        exit 1
    fi
    if ! dos2unix "$tmp"; then
        rm "$tmp"
        echo >&2 "convert fail: $f"
        exit 1
    fi
    mv -- "$tmp" "$name"
done
