#!/bin/sh

run_guest_hid() {
  avp_udid=$(booted_avp_udid)
  exec /usr/bin/swift "$AVP_SIMULATOR_ROOT/lib/guest_hid.swift" "$avp_udid" "$@"
}

run_guest_hid_at_pixel() {
  avp_command=$1
  avp_x=$2
  avp_y=$3
  avp_udid=$(booted_avp_udid)
  set -- $(avp_display_geometry "$avp_udid")
  avp_width=$1
  avp_height=$2
  exec /usr/bin/swift "$AVP_SIMULATOR_ROOT/lib/guest_hid.swift"     "$avp_udid" "$avp_command" "$avp_x" "$avp_y" "$avp_width" "$avp_height"
}
