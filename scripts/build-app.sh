#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${CONFIGURATION:-release}"
swift build -c "$configuration"
bin_path="$(swift build -c "$configuration" --show-bin-path)"
app_path="$PWD/build/FastLangSwitch.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/FastLangSwitch" "$app_path/Contents/MacOS/FastLangSwitch"
cp Support/Info.plist "$app_path/Contents/Info.plist"
swift -swift-version 6 scripts/generate-icon.swift "$PWD/build"
iconutil -c icns "$PWD/build/AppIcon.iconset" -o "$app_path/Contents/Resources/AppIcon.icns"
# Set CODE_SIGN_IDENTITY to a Developer ID or local development certificate for
# a stable TCC identity across builds. Ad-hoc signing works for local evaluation.
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" "$app_path"
printf 'Built %s\n' "$app_path"
