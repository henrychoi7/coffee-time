#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc Sources/Localization.swift Sources/Core.swift Tests/main.swift -o build/CoreTests
build/CoreTests
python3 scripts/check-localizations.py
app='dist/Coffee Time.app/Contents/MacOS/CoffeeTime'
"$app" --integration-test -AppleLanguages '(en-US)'
"$app" --integration-test --expect-korean -AppleLanguages '(ko-KR)'
"$app" --integration-test -AppleLanguages '(fr-FR)'
python3 scripts/power-smoke-test.py
