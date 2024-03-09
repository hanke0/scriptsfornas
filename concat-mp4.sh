#!/usr/bin/env bash

set -Eeo pipefail

usage="
Usage: ${0##*/} [OPTION]... <directory>
Concat all mp4 in the directory to a single mp4.

OPTION:
    -o, --output=FILENAME          output file (default to concat-output.mkv).
    -f, --ffmpeg=EXEC              ffmpeg file path (default to ffmpeg).
    -r, --recursive                search recursively.
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
# require_command

DIR="${PARAMS[0]}"

cd "$DIR"

if [ -z "$FFMPEG" ]; then
    FFMPEG=ffmpeg
fi

depth=(-maxdepth 1 -mindepth 1)
if [ -z "$OUTPUT" ]; then
    OUTPUT="concat-output.mp4"
fi
if [ -n "$RECURSIVE" ]; then
    depth=()
fi

filelist="$(mktemp -p . filelist.XXXXXXXXXX.txt)"

if [ -z "$filelist" ]; then
    echo >&2 "can not create filelist txt"
    exit 1
fi

trap "rm $filelist" EXIT

find . "${depth[@]}" -type f -name '*.mp4' -printf "file '%f'\n" >"$filelist"

"$FFMPEG" -f concat -i "$filelist" -c copy "$OUTPUT"
