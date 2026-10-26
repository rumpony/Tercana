#!/bin/zsh
# Local build → sign with the persistent cert → replace /Applications/SubLens.app → relaunch.
set -e
cd "$(dirname "$0")/.."
xcodegen generate -q
xcodebuild build -project SubLens.xcodeproj -scheme SubLens -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
app=build/Build/Products/Release/SubLens.app
# Set SUBLENS_SIGN_ID to a stable signing identity; ad-hoc ("-") makes macOS re-ask for screen recording after every build.
codesign --force --deep --sign "${SUBLENS_SIGN_ID:--}" --entitlements Resources/SubLens.entitlements "$app"
pkill -x SubLens || true; sleep 1
rm -rf /Applications/SubLens.app && ditto "$app" /Applications/SubLens.app
sleep 1; open -a /Applications/SubLens.app; sleep 2
pgrep -x SubLens >/dev/null && echo "SubLens running" || { echo "SubLens did not start"; exit 1; }
