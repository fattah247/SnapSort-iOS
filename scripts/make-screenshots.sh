#!/bin/zsh
# Regenerates the README screenshots in docs/screenshots.
#
# Builds the demo photo library, sets up a fresh simulator with it, runs the
# screenshot UI test, exports its images, adds a dark mode shot, and cleans up.
# See docs/screenshots.md.
set -euo pipefail

ROOT=${0:A:h:h}
OUT="$ROOT/docs/screenshots"
WORK=$(mktemp -d)
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
# The newest iOS runtime, preferring releases over betas (beta builds end in a letter)
RUNTIME=${RUNTIME:-$(xcrun simctl list runtimes iOS -j | python3 -c '
import json, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"] if r["isAvailable"]]
releases = [r for r in runtimes if r["buildversion"][-1].isdigit()]
print((releases or runtimes)[-1]["identifier"])')}

echo "Building the demo library…"
swiftc -O -suppress-warnings -o "$WORK/scenes" "$ROOT/scripts/demo-library/scenes.swift"
swiftc -O -suppress-warnings -o "$WORK/library" "$ROOT/scripts/demo-library/library.swift"
"$WORK/scenes" "$WORK/scenes-out"
"$WORK/library" "$WORK/scenes-out" "$WORK/library-out"

echo "Preparing a simulator…"
UDID=$(xcrun simctl create "SnapSort Screenshots" "$DEVICE_TYPE" "$RUNTIME")
trap 'xcrun simctl shutdown "$UDID" 2>/dev/null; xcrun simctl delete "$UDID"' EXIT
# US English, so times and dates read naturally in the README. A new simulator
# copies the Mac's region; it's set before the first boot because rebooting to
# apply it can get stuck in a data migration.
DATA=$(xcrun simctl list devices -j | python3 -c '
import json, sys
print(next(d["dataPath"] for ds in json.load(sys.stdin)["devices"].values() for d in ds if d["udid"] == sys.argv[1]))' "$UDID")
plutil -replace AppleLocale -string en_US "$DATA/Library/Preferences/.GlobalPreferences.plist"
plutil -replace AppleLanguages -json '["en-US"]' "$DATA/Library/Preferences/.GlobalPreferences.plist"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl addmedia "$UDID" "$WORK"/library-out/*
# Photos keeps processing new media for a while, which slows everything else down
echo "Letting Photos finish importing…"
sleep 120

echo "Running the screenshot test…"
xcodebuild test -project "$ROOT/SnapSort.xcodeproj" -scheme SnapSort \
  -destination "id=$UDID" -only-testing:SnapSortUITests/ScreenshotTests \
  -resultBundlePath "$WORK/Screenshots.xcresult" -quiet

echo "Exporting…"
mkdir -p "$OUT"
xcrun xcresulttool export attachments --path "$WORK/Screenshots.xcresult" --output-path "$WORK/attachments" > /dev/null
python3 - "$WORK/attachments" "$OUT" <<'PYTHON'
import json, re, subprocess, sys
attachments, out = sys.argv[1], sys.argv[2]
for test in json.load(open(f"{attachments}/manifest.json")):
    for attachment in test.get("attachments", []):
        name = re.sub(r"_\d+_[0-9A-F-]+\.png$", "", attachment["suggestedHumanReadableName"])
        # Half the device resolution is plenty for the README
        subprocess.run(["sips", "-Z", "1311", f"{attachments}/{attachment['exportedFileName']}",
                        "--out", f"{out}/{name}.png"], check=True, capture_output=True)
        print(f"  {name}.png")
PYTHON

# The app keeps its state from the test, so relaunching in dark mode shows the same deck
xcrun simctl ui "$UDID" appearance dark
xcrun simctl launch "$UDID" com.canoe.snapsort > /dev/null
sleep 6
xcrun simctl io "$UDID" screenshot "$WORK/review-dark.png" > /dev/null 2>&1
sips -Z 1311 "$WORK/review-dark.png" --out "$OUT/review-dark.png" > /dev/null
echo "  review-dark.png"

rm -rf "$WORK"
echo "Done."
