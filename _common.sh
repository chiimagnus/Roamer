#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

booted_avp_udid() {
  udid=$(
    xcrun simctl list devices booted |
      sed -nE 's/^[[:space:]]*Apple Vision Pro \(([0-9A-Fa-f-]+)\) \(Booted\).*$/\1/p' |
      head -n 1
  )
  if [ -z "$udid" ]; then
    echo "avp-simulator: 没有已启动的 Apple Vision Pro Simulator。" >&2
    exit 1
  fi
  printf '%s\n' "$udid"
}

avp_display_geometry() {
  udid=${1:-$(booted_avp_udid)}
  info=$(xcrun simctl io "$udid" enumerate)
  width=$(printf '%s\n' "$info" | sed -nE 's/^[[:space:]]*Default width: ([0-9]+)$/\1/p' | head -n 1)
  height=$(printf '%s\n' "$info" | sed -nE 's/^[[:space:]]*Default height: ([0-9]+)$/\1/p' | head -n 1)
  if [ -z "$width" ] || [ -z "$height" ]; then
    echo "avp-simulator: 无法读取 AVP guest display 尺寸。" >&2
    exit 1
  fi
  printf '%s %s\n' "$width" "$height"
}

run_guest_hid() {
  udid=$(booted_avp_udid)
  exec /usr/bin/swift "$SCRIPT_DIR/guest_hid.swift" "$udid" "$@"
}
