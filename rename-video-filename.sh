#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... <video> [videos]...
Rename video file name with template.

TEMPLATE:
    title
    season_episode
    year
    bilingualtitle
    originaltitle

    audio_codec
    audio_codec1
    video_codec
    video_codec1
    resolution
    
OPTION:
    -t, --template            template of filename.
    -y, --yes                 do not ask.
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
require_command ffprobe jq

if [ -z "$TEMPLATE" ]; then
    TEMPLATE='${bilingualtitle}.${year}.${season_episode}.${video_codec}.${resolution}.${audio_codec}'
fi

# export audio_codec audio_codec1
set_audio_infos() {
    local filename data
    filename="$1"
    data="$(ffprobe -show_streams -select_streams a \
        -hide_banner -loglevel error -print_format json "${filename}")"
    audio_codec="$(jq -r '.streams[0].codec_name' <<<"${data}")"
    audio_codec1="$(jq -r '.streams[].codec_name' <<<"${data}" | uniq | xargs)"
}

# export video_codec video_codec1 resolution height width
set_video_infos() {
    local filename data
    filename="$1"
    data="$(ffprobe -show_streams -select_streams v \
        -hide_banner -loglevel error -print_format json "${filename}")"
    video_codec="$(jq -r '.streams[0].codec_name' <<<"${data}")"
    video_codec1="$(jq -r '.streams[].codec_name' <<<"${data}" | uniq | xargs)"
    height="$(jq -r '.streams[0].height' <<<"${data}")"
    width="$(jq -r '.streams[0].width' <<<"${data}")"
    resolution="${width}x${height}"
}

get_title_from_ffprobe() {
    ffprobe -show_entries format_tags=title -of compact=p=0:nk=1 -hide_banner -loglevel error
}

XMLQUERY="$(dirname "$(realpath "$0")")/xmlquery.sh"

# export title season_episode season episode year originaltitle bilingualtitle
set_info_from_nfo() {
    local file
    file="$(filename_base "$1").nfo"
    title="$("$XMLQUERY" 'movie.title' "$file")"
    if [ -z "$title" ]; then
        title="$("$XMLQUERY" 'episodedetails.showtitle' "$file")"
    fi
    originaltitle="$("$XMLQUERY" 'movie.originaltitle' "$file")"
    if [ -z "$originaltitle" ]; then
        originaltitle="$("$XMLQUERY" 'tvshow.originaltitle' "$file")"
    fi
    year="$("$XMLQUERY" 'movie.year' "$file")"
    if [ -z "$year" ]; then
        year="$("$XMLQUERY" 'episodedetails.year' "$file")"
    fi
    if [ "$title" = "$originaltitle" ]; then
        bilingualtitle="$title"
    else
        bilingualtitle="$title.$originaltitle"
    fi

    season="$("$XMLQUERY" 'episodedetails.season' "$file")"
    episode="$("$XMLQUERY" 'episodedetails.episode' "$file")"
    season_episode=
    if [ -n "$season" ] && [ -n "$episode" ]; then
        season_episode="$(printf 'S%02dE%02d' "$season" "$episode")"
    fi
}

doone() {
    local dest jobprompt

    set_info_from_nfo "$1"
    set_audio_infos "$1"
    set_video_infos "$1"

    eval "dest=\"$TEMPLATE\""
    dest="${dest//[^[:alnum:]]/.}"
    dest="$(sed 's/\.\.\.*/./g' <<<"$dest")"
    dest="${dest}.$(filename_ext "$1")"

    jobprompt="mv --'$1' '$(dirname "$1")/$dest'"
    if istrue "$YES"; then
        echo "$jobprompt"
        mv -- "$1" "$(dirname "$1")/$dest"
        return 0
    fi
    if ask_yes "${jobprompt}?[Y/n]" yes; then
        mv -- "$1" "$(dirname "$1")/$dest"
    else
        echo "abort"
    fi
}

for video in "${PARAMS[@]}"; do
    if [ -f "$video" ]; then
        doone "$video"
        continue
    fi
    echo >&2 "Not a video file: $video"
done
