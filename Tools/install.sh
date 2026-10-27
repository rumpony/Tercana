#!/bin/zsh
# Local build → sign with the persistent cert → replace /Applications/Tercana.app → relaunch.
set -e
cd "$(dirname "$0")/.."
xcodegen generate -q
xcodebuild build -project Tercana.xcodeproj -scheme Tercana -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
app=build/Build/Products/Release/Tercana.app
# Set TERCANA_SIGN_ID to a stable signing identity; ad-hoc ("-") makes macOS re-ask for screen recording after every build.
codesign --force --deep --sign "${TERCANA_SIGN_ID:--}" --entitlements Resources/Tercana.entitlements "$app"
pkill -x Tercana || true; sleep 1
rm -rf /Applications/Tercana.app && ditto "$app" /Applications/Tercana.app
sleep 1; open -a /Applications/Tercana.app; sleep 2
pgrep -x Tercana >/dev/null && echo "Tercana running" || { echo "Tercana did not start"; exit 1; }
