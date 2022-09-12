#!/usr/bin/env bash

set -e

usage="
Usage: ${0##*/} filename
Create a new standard bash script.
"

. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"

for file in "${PARAMS[@]}"; do
    cat >"$file" <<EOF
#!/usr/bin/env bash

usage="
Usage: \${0##*/} [OPTION]...
XXX

OPTION:

"

. "$(dirname "$(realpath "\$0")")/base-for-all.sh"

getopt_from_usage "\$usage" "\$@"
require_basic_commands

EOF
    chmod +x "$file"
done
