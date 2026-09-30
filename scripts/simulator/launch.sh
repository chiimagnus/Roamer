#!/bin/sh
set -eu
if [ "$#" -ne 1 ]; then
  echo '用法: launch.sh <bundle-id>' >&2
  exit 2
fi

AVP_SIMULATOR_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$AVP_SIMULATOR_ROOT/lib/simulator.sh"

udid=$(booted_avp_udid)
xcrun simctl launch "$udid" "$1"
