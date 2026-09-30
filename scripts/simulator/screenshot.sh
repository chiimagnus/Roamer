#!/bin/sh
set -eu
AVP_SIMULATOR_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$AVP_SIMULATOR_ROOT/lib/simulator.sh"

path=${1:-/tmp/avp-simulator.png}
udid=$(booted_avp_udid)
xcrun simctl io "$udid" screenshot "$path" >/dev/null
printf '%s\n' "$path"
