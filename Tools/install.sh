#!/bin/zsh
# Local build → sign with the persistent cert → replace /Applications/SubLens.app → relaunch.
set -e
cd "$(dirname "$0")/.."
xcodegen generate -q
xcodebuild build -project SubLens.xcodeproj -scheme SubLens -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
app=build/Build/Products/Release/SubLens.app
codesign --force --deep --sign "${SUBLENS_SIGN_ID:-E7BC42E087BC4D18FED4FF8A263E9F627084F9E4}" --entitlements Resources/SubLens.entitlements "$app"
pkill -x SubLens || true; sleep 1
rm -rf /Applications/SubLens.app && ditto "$app" /Applications/SubLens.app
sleep 1; open -a /Applications/SubLens.app; sleep 2
pgrep -x SubLens >/dev/null && echo "SubLens running" || { echo "SubLens did not start"; exit 1; }
