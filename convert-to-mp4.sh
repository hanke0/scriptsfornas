#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... input output
Convert to mp4 format fit for online viewing.

OPTION:
    -y, --yes     yes to all questions, overwrite output file without asking.
    -c, --codec   codec to use, default to h264.
    -a, --audio   audio codec to use, default to aac.
    -p, --pix_fmt pix_fmt to use, default to yuv420p.
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
# require_command

FFMPEG="${FFMPEG:-ffmpeg}"
FFPROBE="${FFPROBE:-ffprobe}"

input="${PARAMS[0]}"
output="${PARAMS[1]}"
if ! [ -f "$input" ]; then
	echo >&2 "Not a file: $input"
	exit 1
fi

if [ -z "$output" ]; then
	echo >&2 "output not set, try --help for more information"
	exit 1
fi

case "$CODEC" in
h264 | "")
	CODEC="h264"
	;;
hevc)
	CODEC="hevc"
	;;
*)
	echo >&2 "unknown codec: $CODEC, select h264 or hevc"
	exit 1
	;;
esac

case "$AUDIO_CODEC" in
aac | "")
	AUDIO_CODEC="aac"
	;;
*)
	echo >&2 "unknown audio codec: $AUDIO_CODEC, aac is supported"
	exit 1
	;;
esac

case "$PIX_FMT" in
yuv420p | "")
	PIX_FMT="yuv420p"
    ENCODER_PIX_FMT="nv12"
	;;
*)
	echo >&2 "unknown pix_fmt: $PIX_FMT, yuv420p is supported"
	exit 1
	;;
esac

YESOPTION=
if istrue "$YES"; then
	YESOPTION='-y'
fi

audio_codec() {
	"$FFPROBE" -v error -select_streams a:0 \
		-show_entries \
		stream=codec_name -of \
		default=noprint_wrappers=1:nokey=1 \
		"$1"
}

video_codec() {
	"$FFPROBE" -v error -select_streams v:0 \
		-show_entries \
		stream=codec_name -of \
		default=noprint_wrappers=1:nokey=1 \
		"$1"
}

pix_fmt() {
	"$FFPROBE" -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=noprint_wrappers=1:nokey=1 "$1"
}

just_copy() {
	echo >&2 "just copy file: $1 -> $2"
	if istrue "$YES"; then
		cp -f -- "$1" "$2"
	else
		cp -- "$1" "$2"
	fi
}

copy_encode() {
	local args
	args=(
		"$FFMPEG" -hide_banner $YESOPTION
		-i "$1" -map 0
		# video
		-c:v copy
		# audio
		-c:a copy
		# subtitles
		-c:s copy
		# move moov to the beginning of the file to improve online viewing experience
		-movflags +faststart
		"$2"
	)
	vexec "${args[@]}"
}

copy_video_encode() {
	local args
	args=(
		"$FFMPEG" -hide_banner $YESOPTION
		-i "$1" -map 0
		# video
		-c:v copy
		# audio
		-c:a aac -b:a 128k
		# subtitles
		-c:s copy
		# move moov to the beginning of the file to improve online viewing experience
		-movflags +faststart
		"$2"
	)
	vexec "${args[@]}"
}

qsv_encode() {
	local args
	args=(
		"$FFMPEG" -hide_banner $YESOPTION
		-hwaccel qsv -hwaccel_output_format qsv
		-i "$1" -map 0
		# video
		-c:v ${CODEC}_qsv -global_quality 20
		# audio
		-c:a aac -b:a 128k
		# subtitles
		-c:s copy
		-pix_fmt "${ENCODER_PIX_FMT}"
		# move moov to the beginning of the file to improve online viewing experience
		-movflags +faststart
		"$2"
	)
	vexec "${args[@]}"
}

cude_encode() {
	local args
	args=(
		"$FFMPEG" -hide_banner $YESOPTION
		-hwaccel cuda
		-i "$1" -map 0
		-c:v ${CODEC}_nvenc -cq 20
		# audio
		-c:a aac -b:a 128k
		# 字幕
		-c:s copy
		-pix_fmt "${ENCODER_PIX_FMT}"
		# 将视频文件的元信息（moov 块）移动到文件开头。这样，浏览器无需加载完整视频就能开始播放和跳转，极大提升在线观看体验
		-movflags +faststart
		"$2"
	)
	vexec "${args[@]}"
}

is_faststart() {
	local pat
	# moov appears before mdat means faststart
	pat=$("$FFMPEG" -v trace -i "$1" 2>&1 | grep -o -e type:\'mdat\' -e type:\'moov\' | xargs)
	echo >&2 "is_faststart: ${pat}"
	case "$pat" in
	*moov*mdat*)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

is_mp4_format() {
	local fmt
	fmt=$("$FFPROBE" -v error -select_streams v:0 -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$1")
	echo >&2 "video_format: $fmt"
	case "$fmt" in
	*mp4*)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

support_hwaccel() {
	"$FFMPEG" -hide_banner -hwaccels 2>&1 | grep -q "$1" >/dev/null 2>&1
}

codec="$(video_codec "$input")_$(audio_codec "$input")"
pix_fmt="$(pix_fmt "$input")"
echo >&2 "-- PIX_FMT: ${pix_fmt}"
codec="${codec}_${pix_fmt}"
if is_faststart "$input"; then
	codec="${codec}_faststart"
else
	codec="${codec}_notfaststart"
fi
if is_mp4_format "$input"; then
	codec="${codec}_mp4"
else
	codec="${codec}_notmp4"
fi

echo >&2 "-- CODEC: ${codec}"

case "$codec" in
${CODEC}_${AUDIO_CODEC}_${PIX_FMT}_faststart_mp4)
	just_copy "$input" "$output"
	;;
${CODEC}_${AUDIO_CODEC}_${PIX_FMT}_*)
	copy_encode "$input" "$output"
	;;
${CODEC}_*_${PIX_FMT}_*)
	copy_video_encode "$input" "$output"
	;;
*)
	if support_hwaccel "cuda"; then
		cude_encode "$input" "$output"
	else
		qsv_encode "$input" "$output"
	fi
	;;
esac
