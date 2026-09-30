#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/_common.sh"
udid=$(booted_avp_udid)
printf 'UDID=%s\n' "$udid"
xcrun simctl list devices booted
