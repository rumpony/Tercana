#!/bin/zsh
# Renders the UI with mock data into PNGs. Usage: Tools/Preview/run.sh <output-dir> [languages, e.g. tr,en]
set -e
cd "$(dirname "$0")/../.."
out=${1:-/tmp/sublens-preview}
langs=${2:-tr}
bin=$(mktemp -d)/preview
swiftc -swift-version 5 -target arm64-apple-macos26.0 -sdk "$(xcrun --show-sdk-path)" -o "$bin" \
  $(find Sources -name '*.swift' ! -name 'SubLensApp.swift') Tools/Preview/main.swift
SUBLENS_PREVIEW=1 "$bin" "$out" "$PWD/Tools/Preview/assets" "$langs"
