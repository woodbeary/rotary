#!/usr/bin/env bash
# Captures real Rotary screenshots and a screen recording from the iOS Simulator,
# using the app's DEBUG-only fixture launch path (no real account or backend needed).
#
# Run on a Mac with Xcode 16 or newer and xcodegen installed:
#   ./scripts/capture-rotary.sh   (uses ../rotary-ios by default)
#
# Output lands in ./media/rotary-real/.
set -euo pipefail

ROTARY_DIR="${ROTARY_DIR:-$(cd "$(dirname "$0")/../rotary-ios" && pwd)}"
[ -d "$ROTARY_DIR/Vendor/TwilioVoice.xcframework" ] || { echo "Add TwilioVoice.xcframework 6.13.6 to $ROTARY_DIR/Vendor first."; exit 1; }
DEVICE_NAME="${DEVICE_NAME:-iPhone 16 Pro}"
BUNDLE_ID="${ROTARY_BUNDLE_ID:-com.theinterpretingapp.rotaryapp}"
OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/media/rotary-real"
DERIVED="$(mktemp -d)/derived"
mkdir -p "$OUT_DIR"

echo "Building Rotary (Debug, simulator) from $ROTARY_DIR"
( cd "$ROTARY_DIR" && xcodegen generate >/dev/null )
xcodebuild -project "$ROTARY_DIR/Rotary.xcodeproj" -scheme Rotary -configuration Debug \
  -sdk iphonesimulator -destination "platform=iOS Simulator,name=$DEVICE_NAME" \
  -derivedDataPath "$DERIVED" build CODE_SIGNING_ALLOWED=NO | tail -n 3
APP="$(find "$DERIVED/Build/Products" -name 'Rotary.app' -maxdepth 3 | head -n 1)"

UDID="$(xcrun simctl list devices available | grep -m1 "$DEVICE_NAME (" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance dark
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl install "$UDID" "$APP"

# Fixture session: these values only unlock the DEBUG fixture path; they are not real credentials.
export SIMCTL_CHILD_ROTARY_DEBUG_EMAIL="demo@rotary.local"
export SIMCTL_CHILD_ROTARY_DEBUG_SESSION_TOKEN="fixture-session"
export SIMCTL_CHILD_ROTARY_USE_CACHED_BOOTSTRAP_ONLY="1"
export SIMCTL_CHILD_ROTARY_DEBUG_SKIP_FIRST_RUN_ONBOARDING="1"

shot() { # name, seconds to wait, then extra KEY=VALUE pairs for the launch
  local name="$1" wait="$2"; shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  env "$@" xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$OUT_DIR/$name.png" >/dev/null
  echo "  $name.png"
}

echo "Capturing screens into $OUT_DIR"
shot agents   6 SIMCTL_CHILD_ROTARY_DEBUG_ACTION=open_tab SIMCTL_CHILD_ROTARY_DEBUG_TAB=agents
shot messages 5 SIMCTL_CHILD_ROTARY_DEBUG_ACTION=open_tab SIMCTL_CHILD_ROTARY_DEBUG_TAB=messages
shot calls    5 SIMCTL_CHILD_ROTARY_DEBUG_ACTION=open_tab SIMCTL_CHILD_ROTARY_DEBUG_TAB=calls

# The agent call workflow (the app's built-in demo run), recorded as video plus three stills.
PROMPT='Get my lawn mowed tomorrow, under $95'
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT_DIR/agent-workflow.mp4" &
REC=$!
sleep 1
env SIMCTL_CHILD_ROTARY_DEBUG_ACTION=agent_workflow SIMCTL_CHILD_ROTARY_DEBUG_PROMPT="$PROMPT" \
    SIMCTL_CHILD_ROTARY_DEBUG_AUTO_APPROVE=true xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
for t in 3 4 5; do sleep "$t"; xcrun simctl io "$UDID" screenshot "$OUT_DIR/workflow-$t.png" >/dev/null; echo "  workflow-$t.png"; done
sleep 4
kill -INT "$REC"; wait "$REC" 2>/dev/null || true
echo "  agent-workflow.mp4"

xcrun simctl status_bar "$UDID" clear
echo "Done. Swap these into the README in place of the rebuilt stills."
