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

run_devicehub() {
  exec /usr/bin/swift "$SCRIPT_DIR/devicehub.swift" "$@"
}
