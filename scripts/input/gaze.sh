#!/bin/sh
set -eu
if [ "$#" -ne 2 ]; then
  echo '用法: gaze.sh <x-px> <y-px>  # 坐标来自 scripts/simulator/screenshot.sh 生成的 guest PNG' >&2
  exit 2
fi

AVP_SIMULATOR_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$AVP_SIMULATOR_ROOT/lib/simulator.sh"
. "$AVP_SIMULATOR_ROOT/lib/hid.sh"

run_guest_hid_at_pixel gaze-pixel "$1" "$2"
