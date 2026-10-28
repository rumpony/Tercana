#!/bin/zsh
# Builds Tercana for iPhone and installs it on the connected phone.
# Needs: Xcode → Settings → Accounts signed in with an Apple ID, the iPhone connected (cable or same Wi-Fi)
# with Developer Mode on. Usage: iOS/install.sh   (TEAM=XXXXXXXXXX to pick a team explicitly)
set -e
cd "$(dirname "$0")"
xcodegen -q
team=${TEAM:-$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null | grep -m1 -o 'teamID = [A-Z0-9]*' | awk '{print $3}')}
[[ -n $team ]] || { echo "No team: sign in under Xcode → Settings → Accounts first."; exit 1; }
list=$(mktemp)
xcrun devicectl list devices --json-output "$list" >/dev/null 2>&1 || true
device=$(python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))["result"]["devices"]
print(next((x["identifier"] for x in d if x["hardwareProperties"].get("deviceType")=="iPhone"),""))' "$list" 2>/dev/null)
[[ -n $device ]] || { echo "No iPhone found: connect it and unlock it."; exit 1; }
xcodebuild -project TercanaMobile.xcodeproj -scheme TercanaMobile -configuration Release \
  -destination "generic/platform=iOS" -derivedDataPath build -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=$team build | grep -E "error:|BUILD" || true
xcrun devicectl device install app --device "$device" build/Build/Products/Release-iphoneos/Tercana.app
xcrun devicectl device process launch --device "$device" com.rumpony.TercanaMobile || \
  echo "Installed. First run: iPhone Settings → General → VPN & Device Management → trust the developer."
