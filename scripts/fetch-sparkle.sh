#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=2.10.1
sha256=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
archive="$PWD/.cache/Sparkle-$version.tar.xz"
mkdir -p .cache
if [ ! -f "$archive" ]; then
  curl --fail --location --retry 3 "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz" -o "$archive.download"
  mv "$archive.download" "$archive"
fi
printf '%s  %s\n' "$sha256" "$archive" | shasum -a 256 -c -
if [ "$(cat .cache/sparkle/.verified-version 2>/dev/null || true)" != "$version" ]; then
  mkdir -p .cache/sparkle
  tar -xf "$archive" -C .cache/sparkle
  printf '%s\n' "$version" > .cache/sparkle/.verified-version
fi
