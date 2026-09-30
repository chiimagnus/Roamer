#!/bin/sh
set -eu
AVP_SIMULATOR_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$AVP_SIMULATOR_ROOT/lib/simulator.sh"

udid=$(booted_avp_udid)
printf 'UDID=%s\n' "$udid"
xcrun simctl list devices booted
