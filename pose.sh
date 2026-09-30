#!/bin/sh
set -eu
if [ "$#" -ne 1 ]; then
  echo '用法: pose.sh <yaw-deg>' >&2
  exit 2
fi
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/_common.sh"
run_guest_hid pose "$1"
