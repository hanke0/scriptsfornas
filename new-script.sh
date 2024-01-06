#!/usr/bin/env bash

set -e

usage="
Usage: ${0##*/} filename
Create a new standard bash script.
"

# shellcheck source=/dev/null
. "$(dirname -- "$(realpath -- "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"

for file in "${PARAMS[@]}"; do
    cat >"$file" <<'EOF'
#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]...
XXX

OPTION:

"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
# require_command

EOF
    chmod +x "$file"
done
