#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/dist/Coffee Time.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build
xcrun swiftc -O -swift-version 5 -target arm64-apple-macos13.0 Sources/*.swift -o "$APP/Contents/MacOS/CoffeeTime" -framework AppKit -framework SwiftUI -framework IOKit -framework UserNotifications -framework ServiceManagement
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf '%s\n' "$APP"
