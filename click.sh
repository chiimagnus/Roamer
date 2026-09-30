#!/bin/sh
set -eu
if [ "$#" -ne 2 ]; then
  echo '用法: click.sh <x-px> <y-px>  # 坐标来自 screenshot.sh 生成的 guest PNG' >&2
  exit 2
fi
x=$1
y=$2
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/_common.sh"
udid=$(booted_avp_udid)
set -- $(avp_display_geometry "$udid")
width=$1
height=$2
exec /usr/bin/swift "$SCRIPT_DIR/guest_hid.swift" "$udid" click-pixel "$x" "$y" "$width" "$height"
