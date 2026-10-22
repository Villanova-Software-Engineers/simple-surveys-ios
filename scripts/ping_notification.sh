#!/usr/bin/env bash
# ==============================================================================
# Ping Simulated Survey Push Notification to Booted iOS Simulator
# ==============================================================================

set -euo pipefail

BUNDLE_ID="devplaceholder.P3D2XSQM.Simple-Surveys-IOS"
TITLE="${1:-"Study Survey Window Open 🔔"}"
BODY="${2:-"Your scheduled survey window is active. Tap here to complete your responses."}"
SURVEY_ID="${3:-"survey-daily-checkin"}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

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

echo "📡 Pinging notification to booted simulator..."
echo "${PAYLOAD}" | xcrun simctl push booted "${BUNDLE_ID}" -
echo "✅ Notification delivered to simulator!"
