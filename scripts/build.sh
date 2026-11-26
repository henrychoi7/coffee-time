#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/fetch-sparkle.sh
app="$PWD/dist/Coffee Time.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks" build
xcrun swiftc -O -swift-version 5 -target arm64-apple-macos13.0 Sources/*.swift \
  -o "$app/Contents/MacOS/CoffeeTime" -F .cache/sparkle -framework Sparkle \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  -framework AppKit -framework SwiftUI -framework IOKit -framework UserNotifications -framework ServiceManagement
ditto .cache/sparkle/Sparkle.framework "$app/Contents/Frameworks/Sparkle.framework"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/"
cp THIRD_PARTY_NOTICES.txt "$app/Contents/Resources/"
# Overrides are used only for testing an update from an older build.
if [ -n "${COFFEE_VERSION:-}" ]; then /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $COFFEE_VERSION" "$app/Contents/Info.plist"; fi
if [ -n "${COFFEE_BUILD:-}" ]; then /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $COFFEE_BUILD" "$app/Contents/Info.plist"; fi
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
printf '%s\n' "$app"
