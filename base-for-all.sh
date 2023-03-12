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
        if [[ "$line" =~ [[:space:]]+(-[a-z])?[[:space:],]*(--[a-z\-]+)(=([A-Z]+))? ]]; then
            short="${BASH_REMATCH[1]}"
            long="${BASH_REMATCH[2]}"
            optarg="${BASH_REMATCH[4]}"
            if [ -z "$short" ]; then
                matchstring="$long)"
            else
                matchstring="$short|$long)"
            fi
            varname="${long#--*}"    # trim --
            varname="${varname^^}"   # upper
            varname="${varname/-/_}" # replace - to _
            if [ -z "$optarg" ]; then
                casestring="    $varname=1; shift 1"
            else
                casestring="    $varname=\"\$2\"; shift 2"
            fi
            evalstring="$(echo -e "$evalstring\n$matchstring\n$casestring\n    ;;\n")"

            if [ -z "$optarg" ]; then
                continue
            fi
            # support --option=value
            if [ -z "$short" ]; then
                matchstring="${long}=*)"
            else
                matchstring="${short}=*|${long}=*)"
            fi
            casestring="    ${varname}=\${1#*=}; shift 1"
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
        # supporting using -- to skip option parse
        if [ "$1" == "--" ]; then
            shift 1
            PARAMS+=("$@")
            break
        fi
        eval "$evalstring"
    done
}

# Test if the option variable has set.
# Input Variable name
# Output bool true if option value has set.
option_has_set() {
    eval "test ! -z \${$1+x}"
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

videoext=(
    mkv mp4 avi rm rmbv mts m2ts ts webm flv vob ogv ogg drc mov qt wmv
    mepg mpg m2v m3v svi 3go f4v
)

video_find_ext=()
_setup_video_find_ext() {
    for i in "${videoext[@]}"; do
        if [ "${#video_find_ext[@]}" -gt 0 ]; then
            video_find_ext+=(-o -iname "*.$i")
        else
            video_find_ext+=(-iname "*.$i")
        fi

    done
}
_setup_video_find_ext
unset _setup_video_find_ext

find_video_files() {
    find "$@" -type f \( "${video_find_ext[@]}" \)
}

filename_ext() {
    echo "${1##*.}"
}

filename_base() {
    local filename
    filename="$(basename "$1")"
    echo "${filename%.*}"
}

is_video_file() {
    local ext fext
    fext="$(filename_ext "$1")"
    for ext in "${videoext[@]}"; do
        if [ "$ext" = "$fext" ]; then
            return 0
        fi
    done
    return 1
}

require_command() {
    local c
    for c in "$@"; do
        if ! command -v "$c" >/dev/null; then
            echo >&2 "command $c must installed, try 'sudo apt install $c' or 'sudo yum install $c'"
            exit 1
        fi
    done
}

require_basic_commands() {
    require_command find grep awk sed mkdir dirname realpath ps ln echo printf eval test ls
}
