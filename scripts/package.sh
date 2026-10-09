#!/usr/bin/env bash
set -euo pipefail

team_id="${TEAM_ID:-${1:-}}"
if [[ -z "$team_id" ]]; then
  echo "Usage: make package TEAM_ID=YOUR_APPLE_TEAM_ID"
  exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$root/native/build"
project="$root/native/ConsumeCreate.xcodeproj"
app="$build_dir/Build/Products/Release/consume-create.app"
dist="$root/dist"

xcodebuild \
  -project "$project" \
  -scheme ConsumeCreate \
  -configuration Release \
  -derivedDataPath "$build_dir" \
  DEVELOPMENT_TEAM="$team_id" \
  CONSUME_CREATE_GROUP="$team_id.com.consumecreate.shared" \
  build

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
mkdir -p "$dist"
archive="$dist/consume-create-$version-macos.zip"
rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
echo "Created $archive"
