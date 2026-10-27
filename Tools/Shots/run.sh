#!/bin/zsh
# Store screenshots with mock data. Usage: Tools/Shots/run.sh <out-dir> [en|tr]
set -e
cd "$(dirname "$0")/../.."
bin=$(mktemp -d)/shots
swiftc -swift-version 5 -target arm64-apple-macos26.0 -sdk "$(xcrun --show-sdk-path)" -o "$bin" \
  $(find Sources -name '*.swift' ! -name 'TercanaApp.swift') Tools/Shots/main.swift
TERCANA_PREVIEW=1 "$bin" "${1:-/tmp/tercana-shots}" "${2:-en}"
