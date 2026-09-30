#!/bin/sh

booted_avp_udid() {
  avp_udid=$(
    xcrun simctl list devices booted |
      sed -nE 's/^[[:space:]]*Apple Vision Pro \(([0-9A-Fa-f-]+)\) \(Booted\).*$/\1/p' |
      head -n 1
  )
  if [ -z "$avp_udid" ]; then
    echo "avp-simulator: 没有已启动的 Apple Vision Pro Simulator。" >&2
    exit 1
  fi
  printf '%s\n' "$avp_udid"
}

avp_display_geometry() {
  avp_udid=${1:-$(booted_avp_udid)}
  avp_info=$(xcrun simctl io "$avp_udid" enumerate)
  avp_width=$(printf '%s\n' "$avp_info" | sed -nE 's/^[[:space:]]*Default width: ([0-9]+)$/\1/p' | head -n 1)
  avp_height=$(printf '%s\n' "$avp_info" | sed -nE 's/^[[:space:]]*Default height: ([0-9]+)$/\1/p' | head -n 1)
  if [ -z "$avp_width" ] || [ -z "$avp_height" ]; then
    echo "avp-simulator: 无法读取 AVP guest display 尺寸。" >&2
    exit 1
  fi
  printf '%s %s\n' "$avp_width" "$avp_height"
}
