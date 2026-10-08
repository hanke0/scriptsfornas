#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]...
Collect all pictures or videos into folers named by date.

OPTION:
    -p,--picture  collect pictures.
    -v,--video    collect videos.
    -m,--mtime    use file modification time instead of date in filename.
    -n,--dryrun   dry run mode.
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
require_command find
workspace="${PARAMS[0]:-.}"
cd "${workspace}"

date_pattern='2[0-9]{3}[0-9]{2}[0-9]{2}|2[0-9]{3}-[0-9]{2}-[0-9]{2}'

file_ext_find_pattern() {
	local exts tmpflag
    exts=()
	if istrue "$PICTURE"; then
		exts+=(jpg jpeg png gif webp arw heic heif)
	fi
	if istrue "$VIDEO"; then
		exts+=(mp4 mov avi mkv flv wmv wav)
	fi
	echo '('
	tmpflag=0
	for ext in "${exts[@]}"; do
		if [ "$tmpflag" -eq 1 ]; then
			echo '-o'
		fi
		echo '-iname' "*.${ext}"
		tmpflag=1
	done
	echo ')'
}

run_command() {
    print_command "$@"
    if istrue "$DRYRUN"; then
        return
    else
        "$@"
    fi
}

find_dates() {
	local args exts tmpflag dates year month day
	args=(
		find . -maxdepth 1 -mindepth 1 -type f
	)
	args+=($(file_ext_find_pattern))
	args+=(-printf "%f\n")
	dates=$("${args[@]}" | grep -Eo "${date_pattern}" | sort -u)
	for date in $dates; do
		if [[ "$date" =~ ^(2[0-9]{3})\-?([0-9]{2})\-?([0-9]{2})$ ]]; then
			year="${BASH_REMATCH[1]}"
			month="${BASH_REMATCH[2]}"
			day="${BASH_REMATCH[3]}"
			if [ -z "$year" ] || [ -z "$month" ] || [ -z "$day" ]; then
				continue
			fi
			run_command mkdir -p "$year-$month-$day"
			echo "$year" "$month" "$day"
        else
            echo >&2 "bad date format: $date"
		fi
	done
}

mv_files_to_date_folder() {
	local args year month day file mvopt
	year="$1"
	month="$2"
	day="$3"
	args=(
		find . -maxdepth 1 -mindepth 1 -type f
		\( -name "*${year}-${month}-${day}*" -o -name "*${year}${month}${day}*" \)
	)
	args+=($(file_ext_find_pattern))
	args+=(-print0)

	mvopt=(
		mv -v -u -i --
	)
	while IFS= read -r -d '' file; do
		run_command "${mvopt[@]}" "$(pwd)/$file" "$(pwd)/$year-$month-$day/"
	done < <("${args[@]}")
}

do_all_dates() {
	while [ "$#" -gt 0 ]; do
		mv_files_to_date_folder "$1" "$2" "$3"
		shift 3
	done
}

collect_by_mtime() {
	local args date file mvopt
	args=(
		find . -maxdepth 1 -mindepth 1 -type f
	)
	args+=($(file_ext_find_pattern))
	args+=(-printf '%TY-%Tm-%Td\t%p\0')

	mvopt=(
		mv -v -u -i --
	)
	while IFS=$'\t' read -r -d '' date file; do
		[ -n "$date" ] && [ -n "$file" ] || continue
		run_command mkdir -p "$date"
		run_command "${mvopt[@]}" "$(pwd)/$file" "$(pwd)/$date/"
	done < <("${args[@]}")
}

if istrue "$MTIME"; then
	collect_by_mtime
else
	do_all_dates $(find_dates)
fi
