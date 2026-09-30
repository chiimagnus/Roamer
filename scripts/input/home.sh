#!/bin/sh
set -eu
AVP_SIMULATOR_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$AVP_SIMULATOR_ROOT/lib/simulator.sh"
. "$AVP_SIMULATOR_ROOT/lib/hid.sh"

run_guest_hid home
