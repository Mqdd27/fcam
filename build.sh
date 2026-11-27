#!/bin/sh
# Builds a universal (arm64 + x86_64) fcam.app. VERSION env sets the bundle version.
set -e
cd "$(dirname "$0")"
APP=fcam.app
VERSION=${VERSION:-1.0.0}
rm -rf "$APP" build
mkdir -p "$APP/Contents/MacOS" build
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.fcam</string>
  <key>CFBundleName</key><string>fcam</string>
  <key>CFBundleExecutable</key><string>fcam</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSCameraUsageDescription</key><string>Show your facecam in a floating window.</string>
</dict></plist>
EOF
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos14 main.swift -o build/fcam-$arch
done
lipo -create build/fcam-arm64 build/fcam-x86_64 -output "$APP/Contents/MacOS/fcam"
rm -rf build
codesign --force -s - "$APP"
echo "Built $APP $VERSION ($(du -sh "$APP" | cut -f1))"
