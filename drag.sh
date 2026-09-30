#!/bin/sh
set -eu
if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
  echo '用法: drag.sh <from-x-px> <from-y-px> <to-x-px> <to-y-px> [duration-ms]' >&2
  exit 2
fi
from_x=$1
from_y=$2
to_x=$3
to_y=$4
duration=${5:-450}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/_common.sh"
udid=$(booted_avp_udid)
set -- $(avp_display_geometry "$udid")
width=$1
height=$2
exec /usr/bin/swift "$SCRIPT_DIR/guest_hid.swift" "$udid" drag-pixel "$from_x" "$from_y" "$to_x" "$to_y" "$duration" "$width" "$height"
