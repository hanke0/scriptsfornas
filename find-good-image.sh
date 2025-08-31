#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... <folder> [folder]...
Find good image(rating>0) in folder

OPTION:
    -r, --min-rating        rating should greater or equal than this value(default to 1).
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
require_command exiftool

rating=1
if option_has_set "MIN_RATING"; then
    rating=$MIN_RATING
fi
if [ -z "$rating" ]; then
    rating=1
fi

find_in_folder() {
    local folder
    folder="$1"
    if [ -z "${folder}" ]; then
        echo >&2 "bad folder"
        return 1
    fi
    exiftool -FileName -Rating "${folder}" -ext jpg -ext jpeg -ext png -ext arw | awk "$(
        cat <<__EOF__
BEGIN {FS=": "; IGNORECASE = 1}
/^File Name/ {filename=\$2}
/^Rating/ && \$2 > $rating && filename ~ ".(jpg|jpeg|png|arw)$" {print filename}
__EOF__
    )" | xargs -n1 --no-run-if-empty printf "%s/%s\n" "${folder}"
}

for folder in "${PARAMS[@]}"; do
    while IFS= read -r -d '' sub; do
        find_in_folder "$sub"
    done < <(find "${folder}" -type d -not -regex '.*@eaDir.*' -print0)
done
