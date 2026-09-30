#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/_common.sh"
bundle_id=${1:-com.chiimagnus.HappyPianistAVP}
udid=$(booted_avp_udid)
xcrun simctl launch "$udid" "$bundle_id"
