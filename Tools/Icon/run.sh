#!/bin/zsh
# Regenerates every AppIcon size and the website icon from Sources/App/BrandMark.swift.
set -e
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
swiftc -O -o "$tmp/icon" Sources/App/BrandMark.swift Tools/Icon/main.swift
"$tmp/icon" "$tmp/icon1024.png"
set=Resources/Assets.xcassets/AppIcon.appiconset
for s in 16 32 128 256 512; do
  sips -z $s $s "$tmp/icon1024.png" --out "$set/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$tmp/icon1024.png" --out "$set/icon_${s}x${s}@2x.png" >/dev/null
done
cp "$tmp/icon1024.png" docs/assets/icon.png
