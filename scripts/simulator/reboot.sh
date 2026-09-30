#!/bin/sh
set -eu
AVP_SIMULATOR_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$AVP_SIMULATOR_ROOT/lib/simulator.sh"

udid=$(booted_avp_udid)
xcrun simctl shutdown "$udid"
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b
printf 'rebooted %s\n' "$udid"
