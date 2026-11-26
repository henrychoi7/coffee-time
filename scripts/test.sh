#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc Sources/Core.swift Tests/main.swift -o build/CoreTests
build/CoreTests
'dist/Coffee Time.app/Contents/MacOS/CoffeeTime' --integration-test
python3 scripts/power-smoke-test.py
