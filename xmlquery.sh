#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... <expression> [file]
Query xml field from file and print all results.

Examples:

# <movie><actor><name>foo</name></actor><tag><name>bar</name></tag></movie>
>> ${0##*/} 'movie.actor.name' movie.xml
foo

>> ${0##*/} 'movie.*name' movie.xml
foo
bar

OPTION:

"

# shellcheck source=/dev/null
. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands
require_command python3

pyscript="$(
    cat <<EOF
import sys
from xml.dom.minidom import parse, Element, Text

expression = sys.argv[1].split(".")
if len(sys.argv) < 3:
    doc = parse(sys.stdin)
else:
    doc = parse(sys.argv[2])

def query(node, names, id):
    if id >= len(names):
        if not isinstance(node.firstChild, Text):
            return
        if not node.firstChild.data.isspace():
            print(node.firstChild.data)
        return
    field = names[id]
    if field[0] == "*":
        field = field[1:]
        list = node.getElementsByTagName(field)
        if list:
            for sub in list:
                if sub.tagName == field:
                    query(sub, names, id+1)

    if not node.hasChildNodes():
        return
    for sub in node.childNodes:
        if not isinstance(sub, Element):
            continue
        if sub.tagName == field:
            query(sub, names, id+1)

query(doc, expression, 0)
EOF
)"
python3 -c "${pyscript}" "$@"
