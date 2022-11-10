#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... FROM TO [FILE]...
Rename by regex.

OPTION:
    -y, --yes           not asking.
    -n --noexec        show commands instead of executing them.
"

. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands

FROM="${PARAMS[0]}"
TO="${PARAMS[1]}"
FILES=("${PARAMS[@]:2}")

if [ -z "$FROM" ]; then
    echo >&2 "FROM not set, try --help for more information"
    exit 1
fi
if [ -z "$TO" ]; then
    echo >&2 "TO not set, try --help for more information"
    exit 1
fi

if [ -z "$NOEXEC" ]; then
    move() {
        mv "$@"
    }
else
    move() {
        echo mv "$@"
    }
fi

if [ -z "$YES" ]; then
    do_move() {
        local ans
        printf '%s ' "mv $@ [Y/n]:"
        read -r ans

        case "$ans" in
        "" | Y | y | yes | YES)
            move "$@"
            ;;
        *)
            echo "user abort"
            ;;
        esac
    }
else
    do_move() {
        move "$@"
    }
fi

getto() {
    sed -E 's/\$([0-9]+)/${BASH_REMATCH[\1]}/g' <<<"$1"
}
CTO="$(getto "$TO")"

for file in "${FILES[@]}"; do
    folder="$(dirname "$file")"
    base="$(basename "$file")"
    if [[ ! "$base" =~ $FROM ]]; then
        echo >&2 "file not match regex: $file"
        continue
    fi
    tobase="$(eval "echo $CTO")"
    from="$folder/$base"
    to="$folder/$tobase"
    if [ "$from" != "$to" ]; then
        do_move "$from" "$to"
    fi
done
