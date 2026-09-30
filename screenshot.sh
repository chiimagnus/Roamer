#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/_common.sh"
path=${1:-/tmp/avp-simulator.png}
udid=$(booted_avp_udid)
xcrun simctl io "$udid" screenshot "$path" >/dev/null
printf '%s\n' "$path"
