#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... <directory-contains-video> <target-directory>
Consolidate all videos into a single directory.

OPTION:

"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
# require_command
