#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/_common.sh"
path=${1:-/tmp/avp-device-hub.png}
run_devicehub screenshot "$path"
