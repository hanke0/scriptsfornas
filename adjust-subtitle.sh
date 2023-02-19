#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]...
Adjust subtitle to syncing to pictures.

OPTION:
    -o --overwrite               overwrite instead of output stdout.
    -d --duration=Miliseconds    shift duration (default to 0).
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands

if [ -z "$DURATION" ]; then
    DURATION=0
fi

if [[ ! "$DURATION" =~ \-?[0-9]+ ]]; then
    echo >&2 "bad shift duration $DURATION"
    exit 1
fi

add_duration() {
    local hour minute sec msec style duration
    style="$1"
    hour="$2"
    minute="$3"
    sec="$4"
    msec="$5"

    if [ "$style" = ass ]; then
        msec="$((10#$msec * 10))"
    fi

    duration="$(((10#$hour * 3600 + 10#$minute * 60 + 10#$sec) * 1000 + 10#$msec + 10#$DURATION))"

    hour="$((10#$duration / 3600000))"
    duration="$((10#$duration % 3600000))"
    minute="$((10#$duration / 60000))"
    duration="$((10#$duration % 60000))"
    sec="$((10#$duration / 1000))"
    msec="$((10#$duration % 1000))"

    case "$style" in
    ass)
        printf "%d:%02d:%02d.%02d" "$hour" "$minute" "$sec" "$((10#$msec / 10))"
        ;;
    srt)
        printf "%02d:%02d:%02d,%03d" "$hour" "$minute" "$sec" "$msec"
        ;;
    *)
        echo >&2 "bad style: $style"
        exit 1
        ;;
    esac
}

# inspired by https://github.com/xuminic/subsync
adjust_line() {
    local prefix start1 start2 start3 start4 start end1 end2 end3 end4 end suffix
    local sep="[:.,\\-]"
    local num="[0-9]+"
    local assre="^Dialogue:[[:space:]]*([^,]*),($num)$sep($num)$sep($num)$sep($num),($num)$sep($num)$sep($num)$sep($num)(.*)"
    # ass Dialogue: 0,0:04:55.05,0:04:59.55,
    if [[ "$1" =~ $assre ]]; then
        prefix="${BASH_REMATCH[1]}"
        start1="${BASH_REMATCH[2]}"
        start2="${BASH_REMATCH[3]}"
        start3="${BASH_REMATCH[4]}"
        start4="${BASH_REMATCH[5]}"
        end1="${BASH_REMATCH[6]}"
        end2="${BASH_REMATCH[7]}"
        end3="${BASH_REMATCH[8]}"
        end4="${BASH_REMATCH[9]}"
        suffix="${BASH_REMATCH[10]}"

        start="$(add_duration ass "$start1" "$start2" "$start3" "$start4")"
        end="$(add_duration ass "$end1" "$end2" "$end3" "$end4")"
        echo "Dialogue: $prefix,$start,$end$suffix"
        return
    fi

    local srtre="($num)$sep($num)$sep($num)$sep($num)[[:space:]]*-->[[:space:]]*($num)$sep($num)$sep($num)$sep($num)(.*)"
    if [[ "$1" =~ $srtre ]]; then
        start1="${BASH_REMATCH[1]}"
        start2="${BASH_REMATCH[2]}"
        start3="${BASH_REMATCH[3]}"
        start4="${BASH_REMATCH[4]}"
        end1="${BASH_REMATCH[5]}"
        end2="${BASH_REMATCH[6]}"
        end3="${BASH_REMATCH[7]}"
        end4="${BASH_REMATCH[8]}"
        suffix="${BASH_REMATCH[9]}"

        start="$(add_duration srt "$start1" "$start2" "$start3" "$start4")"
        end="$(add_duration srt "$end1" "$end2" "$end3" "$end4")"
        echo "$start --> $end$suffix"
        return
    fi
    echo "$line"
}

adjust_file() {
    if [ -n "$OVERWRITE" ]; then
        output="$1.adjusted"
    else
        output="/dev/stdout"
    fi
    if [ -f "$output" ]; then
        printf "%s" "$output exist overwrite it? [Y/n]"
        ans=
        read -r ans
        case "$ans" in
        Y | yes | y | YES | "")
            echo >"$output"
            ;;
        *)
            return
            ;;
        esac
    fi

    while IFS=$'\n' read -r line; do
        adjust_line "$line" >>"$output"
    done <"$1"

    if [ -n "$OVERWRITE" ]; then
        mv -f "$output" "$1"
    fi
}

for file in "${PARAMS[@]}"; do
    case "$file" in
    *.ass | *.srt)
        adjust_file "$file"
        ;;
    *) ;;
    esac
done
