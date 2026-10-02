#!/bin/bash
set -euo pipefail

fixture_dir="$(cd "$(dirname "$0")" && pwd)"
app_dir="$fixture_dir/../../.build/simulator-fixture/RoamerTestApp.app"
mkdir -p "$app_dir"
xcrun swiftc -parse-as-library \
    -sdk "$(xcrun --sdk xrsimulator --show-sdk-path)" \
    -target arm64-apple-xros27.0-simulator \
    "$fixture_dir"/*.swift -o "$app_dir/RoamerTestApp"
cp "$fixture_dir/Info.plist" "$app_dir/Info.plist"
printf '%s\n' "$app_dir"
