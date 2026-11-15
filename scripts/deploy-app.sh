#!/bin/bash
# Build and install a local development copy; does not require sudo.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh
applications_dir="${APPLICATIONS_DIR:-"$HOME/Applications"}"
destination="$applications_dir/FastLangSwitch.app"
mkdir -p "$applications_dir"
if [[ -e "$destination" || -L "$destination" ]]; then
    rm -r "$destination"
fi
ditto "$PWD/build/FastLangSwitch.app" "$destination"
printf 'Installed %s\n' "$destination"
printf 'Launch with: open %q\n' "$destination"
