#!/usr/bin/env bash
# ==============================================================================
# Ping Simulated Survey Push Notification to Booted iOS Simulator
# ==============================================================================

set -euo pipefail

BUNDLE_ID="com.simplesurveys.ios"
TITLE="${1:-"Study Survey Window Open 🔔"}"
BODY="${2:-"Your scheduled survey window is active. Tap here to complete your responses."}"
SURVEY_ID="${3:-"sample-survey-daily"}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Ensure Simulator app is open and brought to front
open -a Simulator 2>/dev/null || true

# Check if a simulator device is currently booted
BOOTED_DEVICES=$(xcrun simctl list devices | grep "Booted" | awk -F '[()]' '{print $2}' || true)
if [ -z "$BOOTED_DEVICES" ]; then
    echo "📱 No simulator is booted. Booting iPhone simulator..."
    xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || xcrun simctl boot "iPhone 16 Pro" 2>/dev/null || xcrun simctl boot "iPhone 15 Pro" 2>/dev/null || true
    sleep 3
    BOOTED_DEVICES=$(xcrun simctl list devices | grep "Booted" | awk -F '[()]' '{print $2}' || true)
fi

PAYLOAD=$(cat <<EOF
{
  "Simulator Target Bundle": "${BUNDLE_ID}",
  "aps": {
    "alert": {
      "title": "${TITLE}",
      "body": "${BODY}"
    },
    "sound": "default",
    "badge": 1
  },
  "survey_id": "${SURVEY_ID}",
  "notification_sent_at": "${TIMESTAMP}"
}
EOF
)

# Push to every booted simulator so whichever window is in front gets it!
for DEV in $BOOTED_DEVICES; do
    echo "📡 Pinging notification to simulator ($DEV)..."
    echo "${PAYLOAD}" | xcrun simctl push "$DEV" "${BUNDLE_ID}" -
done

echo "✅ Notification delivered to simulator!"
