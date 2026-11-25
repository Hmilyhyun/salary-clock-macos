#!/bin/sh
set -eu
cd "$(dirname "$0")"
swift build -c release
bin=$(swift build -c release --show-bin-path)
bundle="build/Salary Clock.app"
app="$bundle/Contents"
mkdir -p "$app/MacOS" "$app/Resources"
cp "$bin/Clock" "$app/MacOS/Clock"
cp Sources/Clock/Resources/salary.js "$app/Resources/"
cp Assets/Clock.icns "$app/Resources/"
cp Info.plist "$app/"
codesign --force --sign - "$bundle"
