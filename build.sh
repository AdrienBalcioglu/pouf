#!/bin/bash
# Builds Pouf.app (universal) and Pouf.dmg with the Command Line Tools only. No Xcode needed.
set -euo pipefail
cd "$(dirname "$0")"
APP=build/Pouf.app
mkdir -p build "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -swift-version 5 -O -target arm64-apple-macos13.0 Sources/main.swift -o build/pouf-arm64
swiftc -swift-version 5 -O -target x86_64-apple-macos13.0 Sources/main.swift -o build/pouf-x86_64
lipo -create build/pouf-arm64 build/pouf-x86_64 -output "$APP/Contents/MacOS/Pouf"

swiftc -swift-version 5 Sources/icon.swift -o build/mkicon
./build/mkicon build/icon-1024.png
mkdir -p build/Pouf.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon-1024.png --out build/Pouf.iconset/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) build/icon-1024.png --out build/Pouf.iconset/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns build/Pouf.iconset -o "$APP/Contents/Resources/Pouf.icns"
cp Sources/Info.plist "$APP/Contents/Info.plist"
codesign --force --deep -s - "$APP"

STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/Pouf.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname Pouf -srcfolder "$STAGE" -ov -format UDZO Pouf.dmg
echo "Built Pouf.dmg"
