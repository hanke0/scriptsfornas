#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... <directory>
Concat a video in one directory to a single video.

OPTION:
    -o, --output=FILENAME          output file (default to concat-output.mkv).
    -f, --ffmpeg=EXEC              ffmpeg file path (default to ffmpeg).
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

if [ -z "$OUTPUT" ]; then
    OUTPUT="concat-output.mkv"
fi

filelist="$(mktemp -p . filelist.XXXXXXXXXX.txt)"

if [ -z "$filelist" ]; then
    echo >&2 "can not create filelist txt"
    exit 1
fi

trap "rm $filelist" EXIT

callback() {
    local video="$1"
}

find . -type f '(' "${video_find_ext[@]}" ')' -printf "file '%f'\n" >"$filelist"

"$FFMPEG" -f concat -i "$filelist" -c copy "$OUTPUT"
