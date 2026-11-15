#!/bin/bash
# Opt-in integration test. Open the fixture separately; see README.md.
set -euo pipefail
cd "$(dirname "$0")/.."
test_build="$PWD/.build/secure-input-ui-tests"
mkdir -p "$test_build"
swiftc -swift-version 6 -emit-library -emit-module -module-name SwitchCore \
    -emit-module-path "$test_build/SwitchCore.swiftmodule" Sources/SwitchCore/*.swift \
    -o "$test_build/libSwitchCore.dylib"
swiftc -swift-version 6 -I "$test_build" -L "$test_build" -lSwitchCore \
    -Xlinker -rpath -Xlinker @executable_path \
    Sources/FastLangSwitch/KeyboardMonitor.swift Tests/UI/SecureInputMonitorProbe.swift \
    -o "$test_build/Probe"
exec "$test_build/Probe"
