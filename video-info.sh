#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... <filename>
XXX

OPTION:

"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
require_command ffprob jq

filename="${PARAMS[0]}"
if [ -z "$filename" ] || [ ! -f "$filename" ]; then
    echo >&2 "file not exist: $filename"
    exit 1
fi

data="$(ffprobe -v quiet -print_format json -show_format -show_streams "$filename")"

jq -r '.streams[0].height | tostring | .+"p"' <<<"$data"
jq -r '.streams[0].codec_name' <<<"$data"
jq -r '.streams[1].codec_name' <<<"$data"
