#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
tag="${1:?배포할 태그를 지정해 주세요}"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
[ "$tag" = "v$version" ] || { echo '태그와 앱 버전이 다릅니다.' >&2; exit 1; }
release_dir="dist/release-$version"
if ! gh release view "$tag" >/dev/null 2>&1; then
  gh release create "$tag" --verify-tag --draft --title "Coffee Time $version" --notes-file "docs/releases/$version.md"
fi
gh release upload "$tag" "$release_dir/Coffee-Time-$version-arm64.dmg" "$release_dir/Coffee-Time-$version-arm64.zip" "$release_dir/appcast.xml" "$release_dir/SHA256SUMS.txt"
gh release edit "$tag" --draft=false --latest
