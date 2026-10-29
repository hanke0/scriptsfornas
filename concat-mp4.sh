#!/usr/bin/env bash

set -Eeo pipefail

usage="
Usage: ${0##*/} [OPTION]... <directory>...
Concat all videos in the directories (in the given order) to a single mp4.

OPTION:
    -o, --output=FILENAME          output file, relative to the first directory
                                   (default to concat-output.mp4).
    -f, --ffmpeg=EXEC              ffmpeg file path (default to ffmpeg).
    -p, --ffprobe=EXEC             ffprobe file path (default to ffprobe).
    -r, --recursive                search recursively.
    -m, --mode=MODE                concat mode (default to scale):
                                     simple: concat demuxer, all videos must have same resolution and codecs.
                                     group:  group videos by resolution, one output per resolution,
                                             named like concat-output-1920x1080.mp4.
                                     scale:  scale (keep aspect ratio and pad) all videos into one output.
    -s, --size=SIZE                target resolution of scale mode, e.g. 1920x1080
                                   (default to the largest resolution of the videos).
    -v, --verbose                  show full ffmpeg logs.
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
# require_command

dirs=(.)
for dir in "${PARAMS[@]:1}"; do
	dirs+=("$(realpath -e "$dir")")
done

cd "${PARAMS[0]}"

if [ -z "$FFMPEG" ]; then
	FFMPEG=ffmpeg
fi
if [ -z "$FFPROBE" ]; then
	FFPROBE=ffprobe
fi

depth=(-maxdepth 1 -mindepth 1)
if [ -z "$OUTPUT" ]; then
	OUTPUT="concat-output.mp4"
fi
if [ -n "$RECURSIVE" ]; then
	depth=()
fi
MODE="${MODE:-scale}"
case "$MODE" in
simple | group | scale) ;;
*)
	echo >&2 "unknown mode: $MODE"
	exit 1
	;;
esac
if [ -n "$SIZE" ] && ! [[ "$SIZE" =~ ^[0-9]+x[0-9]+$ ]]; then
	echo >&2 "invalid size: $SIZE"
	exit 1
fi
loglevel=(-loglevel warning -stats)
if [ -n "$VERBOSE" ]; then
	loglevel=()
fi

support_hwaccel() {
	"$FFMPEG" -hide_banner -hwaccels 2>&1 | grep -q "$1" >/dev/null 2>&1
}

if support_hwaccel "cuda"; then
	hwdecode=(-hwaccel cuda)
	vencode=(-c:v h264_nvenc -cq 20)
else
	hwdecode=(-hwaccel qsv -hwaccel_output_format qsv)
	vencode=(-c:v h264_qsv -global_quality 20)
fi

simple_concat() {
	local filelist file
	filelist="$(mktemp -p . filelist.XXXXXXXXXX.txt)"
	if [ -z "$filelist" ]; then
		echo >&2 "can not create filelist txt"
		exit 1
	fi
	# shellcheck disable=SC2064
	trap "rm '$filelist'" EXIT
	for file in "${files[@]}"; do
		printf "file '%s'\n" "${file//\'/\'\\\'\'}"
	done >"$filelist"

	vexec "$FFMPEG" -hide_banner "${loglevel[@]}" "${hwdecode[@]}" \
		-f concat -safe 0 -i "$filelist" -map 0 \
		"${vencode[@]}" \
		-c:a aac -b:a 192k \
		-c:s mov_text \
		-movflags +faststart \
		"$1"
}

# Prints WIDTHxHEIGHT of the first video stream, rotation is considered.
probe_resolution() {
	local key value w h rotation
	while IFS='=' read -r key value; do
		case "$key" in
		width) w="$value" ;;
		height) h="$value" ;;
		rotation | TAG:rotate) rotation="$value" ;;
		esac
	done < <("$FFPROBE" -v error -select_streams v:0 \
		-show_entries stream=width,height:stream_tags=rotate:stream_side_data=rotation \
		-of default=nw=1 "$1")
	case "$rotation" in
	90 | -90 | 270 | -270) echo "${h}x${w}" ;;
	*) echo "${w}x${h}" ;;
	esac
}

has_audio() {
	[ -n "$("$FFPROBE" -v error -select_streams a -show_entries stream=index -of csv=p=0 "$1")" ]
}

probe_duration() {
	"$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$1"
}

# Every video is scaled and padded to the size and encoded into a temp file one by one,
# then the temp files are joined by the concat demuxer without re-encoding,
# so only one video is decoded at a time.
# Usage: filter_concat <output> <WIDTHxHEIGHT> <file>...
filter_concat() {
	local output="$1" w h file audio tmpdir i=0 inputs
	w="${2%x*}"
	h="${2#*x}"
	w=$((w / 2 * 2))
	h=$((h / 2 * 2))
	shift 2
	tmpdir="$(mktemp -d -p . concat-tmp.XXXXXXXXXX)"
	# shellcheck disable=SC2064
	trap "rm -rf '$tmpdir'" EXIT
	for file in "$@"; do
		i=$((i + 1))
		echo >&2 "[$i/$#] $file"
		inputs=(-i "$file")
		audio="0:a:0"
		if ! has_audio "$file"; then
			inputs+=(-f lavfi -t "$(probe_duration "$file")" -i anullsrc=r=48000:cl=stereo)
			audio="1:a:0"
		fi
		vexec "$FFMPEG" -hide_banner "${loglevel[@]}" "${inputs[@]}" \
			-filter_complex "[0:v:0]scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2,setsar=1,format=nv12[v];[$audio]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[a]" \
			-map '[v]' -map '[a]' \
			-fps_mode vfr \
			"${vencode[@]}" \
			-c:a aac -b:a 192k \
			-video_track_timescale 90000 \
			"$tmpdir/$i.mp4"
		printf "file '%s'\n" "$i.mp4" >>"$tmpdir/filelist.txt"
	done

	vexec "$FFMPEG" -hide_banner "${loglevel[@]}" \
		-f concat -safe 0 -i "$tmpdir/filelist.txt" -map 0 -c copy \
		-movflags +faststart \
		"$output"
	rm -rf "$tmpdir"
	trap - EXIT
}

output_name="${OUTPUT#./}"
files=()
while IFS= read -r -d '' file; do
	# skip outputs of previous runs
	case "${file#./}" in
	"$output_name" | "${output_name%.*}"-[0-9]*x[0-9]*."${output_name##*.}") continue ;;
	esac
	files+=("$file")
done < <(for dir in "${dirs[@]}"; do
	find "$dir" "${depth[@]}" -type f '(' "${video_find_ext[@]}" ')' -print0 | sort -z
done)

if [ "${#files[@]}" -eq 0 ]; then
	echo >&2 "no video files found"
	exit 1
fi

if [ "$MODE" = simple ]; then
	simple_concat "$OUTPUT"
	exit 0
fi

resolutions=()
for file in "${files[@]}"; do
	resolutions+=("$(probe_resolution "$file")")
	echo >&2 "${resolutions[-1]} $file"
done

if [ "$MODE" = scale ]; then
	if [ -z "$SIZE" ]; then
		max=0
		for res in "${resolutions[@]}"; do
			if [ $((${res%x*} * ${res#*x})) -gt "$max" ]; then
				max=$((${res%x*} * ${res#*x}))
				SIZE="$res"
			fi
		done
	fi
	filter_concat "$OUTPUT" "$SIZE" "${files[@]}"
	exit 0
fi

# group mode
mapfile -t groups < <(printf '%s\n' "${resolutions[@]}" | sort -u)
for res in "${groups[@]}"; do
	group_files=()
	for i in "${!files[@]}"; do
		if [ "${resolutions[$i]}" = "$res" ]; then
			group_files+=("${files[$i]}")
		fi
	done
	filter_concat "${OUTPUT%.*}-${res}.${OUTPUT##*.}" "$res" "${group_files[@]}"
done
