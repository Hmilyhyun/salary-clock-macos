#!/bin/sh
set -eu
cd "$(dirname "$0")"
swift build -c release
bin=$(swift build -c release --show-bin-path)
bundle="build/Salary Clock.app"
mkdir -p build
staging=$(mktemp -d build/.salary-clock.XXXXXX)
trap 'rm -rf "$staging"' 0
stagedBundle="$staging/Salary Clock.app"
app="$stagedBundle/Contents"
mkdir -p "$app/MacOS" "$app/Resources"
cp "$bin/Clock" "$app/MacOS/Clock"
cp Assets/Clock.icns "$app/Resources/"
cp Info.plist "$app/"
codesign --force --sign - "$stagedBundle"
rm -rf "$bundle"
mv "$stagedBundle" "$bundle"
