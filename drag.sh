#!/bin/sh
set -eu
if [ "$#" -lt 4 ] || [ "$#" -gt 6 ]; then
  echo "用法: drag.sh <from-x-px> <from-y-px> <to-x-px> <to-y-px> [duration-ms] [hover-ms]" >&2
  exit 2
fi
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/_common.sh"
run_devicehub drag "$@"
