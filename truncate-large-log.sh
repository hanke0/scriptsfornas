#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... [FILES]...
Trucate larger log into max size.

OPTION:
    -m --max=SIZE        set default max size(default to 64M)
"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
require_command truncate

if [ -z "$MAX" ]; then
    MAX=64M
fi

for f in "${PARAMS[@]}"; do
    if [ -d "$f" ]; then
        find "$f" -type f -print0 | du -t "$MAX" --files0-from=- | awk '{print $2}' | xargs truncate -s 0 || true
        continue
    fi
    if [ -f "$f" ]; then
        du -t "$MAX" "$f" | awk '{print $2}' | xargs truncate -s 0 || true
        continue
    fi
done
