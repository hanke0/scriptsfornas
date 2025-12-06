#!/bin/bash

#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... input [input]...
Check is video streamable. output filename is it not streamable.

OPTION:
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
	;;
*)
	echo >&2 "unknown pix_fmt: $PIX_FMT, yuv420p is supported"
	exit 1
	;;
esac

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

is_faststart() {
	local pat
	# moov appears before mdat means faststart
	pat=$("$FFMPEG" -v trace -i "$1" 2>&1 | grep -o -e type:\'mdat\' -e type:\'moov\' | xargs)
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
	case "$fmt" in
	*mp4*)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

check_streamable() {
	local codec pix_fmt
	codec="$(video_codec "$1")_$(audio_codec "$1")"
	pix_fmt="$(pix_fmt "$1")"
	codec="${codec}_${pix_fmt}"
	if is_faststart "$1"; then
		codec="${codec}_faststart"
	else
		codec="${codec}_notfaststart"
	fi
	if is_mp4_format "$1"; then
		codec="${codec}_mp4"
	else
		codec="${codec}_notmp4"
	fi

	case "$codec" in
	${CODEC}_${AUDIO_CODEC}_${PIX_FMT}_faststart_mp4)
		echo "STREAMABLE ${codec} ${1}"
		;;
	*)
		echo "STREAMLESS ${codec} ${1}"
		;;
	esac
}

for file in "$@"; do
	check_streamable "$file"
done
