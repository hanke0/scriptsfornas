#!/usr/bin/env bash

# Get options from usage string.
# Usage: getopt_from_usage usages [arguments]...
# Treat "-s --long" or "--long" as option arguments
# A long option with equal sign accepts a value.
# Values will be set to UPPER long option.
# A option without equal sign will be set to 1.
# Postional arguments stores at PARAMS.
getopt_from_usage() {
    PARAMS=()
    local line short long optarg evalstring matchstring varname casestring helpstring
    helpstring="$1"
    shift
    while IFS=$'\n' read -r line; do
        if [[ "$line" =~ [[:space:]]+(-[a-z])?[[:space:]]*(--[a-z]+)(=([A-Z]+))? ]]; then
            short="${BASH_REMATCH[1]}"
            long="${BASH_REMATCH[2]}"
            optarg="${BASH_REMATCH[4]}"
            if [ -z "$short" ]; then
                matchstring="$long)"
            else
                matchstring="$short|$long)"
            fi
            varname="${long#--*}"  # trim --
            varname="${varname^^}" # upper
            if [ -z $optarg ]; then
                casestring="    $varname=1; shift 1"
            else
                casestring="    $varname=\"\$2\"; shift 2"
            fi
            evalstring="$(echo -e "$evalstring\n$matchstring\n$casestring\n    ;;\n")"
        fi
    done <<EOF
$helpstring
EOF
    evalstring="$(
        cat <<EOF
case "\$1" in
$evalstring
-h|--help)
    echo "\$helpstring"
    exit 0
    ;;
-*)
    echo >&2 "unknown option: \$1"
    exit 1
    ;;
*)
    PARAMS+=("\$1")
    shift
    ;;
esac
EOF
    )"
    while [ $# -gt 0 ]; do
        eval "$evalstring"
    done
}

vexec() {
    local i
    for i in "$@"; do
        case "-$i-" in
        -*[[:blank:]]*-)
            printf "'%s' " "$i"
            ;;
        *)
            printf "%s " "$i"
            ;;
        esac
    done
    printf "\n"
    "$@"
}

# real_wsl_path_to_win_path gets the real input path and transforms it from the wsl '/mnt/c/...' sytle to 'C:\...' style.
real_wsl_path_to_win_path() {
    realpath "$1" | sed -E 's#^/mnt/([a-zA-Z])/#\U\1:\\#g' | tr / \\\\
}
