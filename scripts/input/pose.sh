#!/bin/sh
set -eu
if [ "$#" -ne 1 ]; then
  echo '用法: pose.sh <yaw-deg>' >&2
  exit 2
fi

AVP_SIMULATOR_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$AVP_SIMULATOR_ROOT/lib/simulator.sh"
. "$AVP_SIMULATOR_ROOT/lib/hid.sh"

run_guest_hid pose "$1"
