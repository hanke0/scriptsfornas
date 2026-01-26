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

qsv_encode() {
	local args
	args=(
		"$FFMPEG" -hide_banner
		-hwaccel qsv -hwaccel_output_format qsv
		-f concat -safe 0
		-i "$1" -map 0
		# video
		-c:v h264_qsv -global_quality 20
		# audio
		-c:a aac -b:a 192k
		# subtitles
		-c:s mov_text
		# move moov to the beginning of the file to improve online viewing experience
		-movflags +faststart
		"$2"
	)
	vexec "${args[@]}"
}

cude_encode() {
	local args
	args=(
		"$FFMPEG" -hide_banner
		-hwaccel cuda
		-f concat -safe 0
		-i "$1" -map 0
		-c:v h264_nvenc -cq 20
		# audio
		-c:a aac -b:a 192k
		# 字幕
		-c:s mov_text
		# 将视频文件的元信息（moov 块）移动到文件开头。这样，浏览器无需加载完整视频就能开始播放和跳转，极大提升在线观看体验
		-movflags +faststart
		"$2"
	)
	vexec "${args[@]}"
}

support_hwaccel() {
	"$FFMPEG" -hide_banner -hwaccels 2>&1 | grep -q "$1" >/dev/null 2>&1
}

filelist="$(mktemp -p . filelist.XXXXXXXXXX.txt)"

if [ -z "$filelist" ]; then
	echo >&2 "can not create filelist txt"
	exit 1
fi

trap "rm $filelist" EXIT

find . "${depth[@]}" -type f -name '*.mp4' -printf "file '%p'\n" >"$filelist"

if support_hwaccel "cuda"; then
	cude_encode "$filelist" "$OUTPUT"
else
	qsv_encode "$filelist" "$OUTPUT"
fi
