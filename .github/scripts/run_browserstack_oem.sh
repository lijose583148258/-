#!/usr/bin/env bash
set -euo pipefail

: "${BROWSERSTACK_USERNAME:?Missing BROWSERSTACK_USERNAME}"
: "${BROWSERSTACK_ACCESS_KEY:?Missing BROWSERSTACK_ACCESS_KEY}"

APP_APK="${APP_APK:-fanyi_app/build/app/outputs/flutter-apk/app-debug.apk}"
TEST_APK="${TEST_APK:-fanyi_app/build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk}"
PROJECT_NAME="${PROJECT_NAME:-FanyiTong OEM acceptance}"
BUILD_TAG="${BUILD_TAG:-${GITHUB_SHA:-local}}"
DEVICE_FAMILIES="${DEVICE_FAMILIES:-xiaomi,oneplus,oppo,realme,honor}"
MIN_ANDROID_MAJOR="${MIN_ANDROID_MAJOR:-10}"
POLL_SECONDS="${POLL_SECONDS:-20}"
MAX_POLLS="${MAX_POLLS:-120}"
API_ROOT="https://api-cloud.browserstack.com/app-automate"
AUTH="${BROWSERSTACK_USERNAME}:${BROWSERSTACK_ACCESS_KEY}"

for file in "$APP_APK" "$TEST_APK"; do
  if [[ ! -f "$file" ]]; then
    echo "Required APK not found: $file" >&2
    exit 2
  fi
done

upload_file() {
  local endpoint="$1"
  local file="$2"
  curl --fail --silent --show-error \
    -u "$AUTH" \
    -X POST "$API_ROOT/espresso/v2/$endpoint" \
    -F "file=@$file"
}

APP_RESPONSE="$(upload_file app "$APP_APK")"
TEST_RESPONSE="$(upload_file test-suite "$TEST_APK")"
APP_URL="$(jq -er '.app_url' <<<"$APP_RESPONSE")"
TEST_URL="$(jq -er '.test_suite_url' <<<"$TEST_RESPONSE")"

DEVICES_JSON="$(curl --fail --silent --show-error -u "$AUTH" "$API_ROOT/devices.json")"
SELECTED_DEVICES="$(
  jq -c \
    --arg families "$DEVICE_FAMILIES" \
    --argjson minMajor "$MIN_ANDROID_MAJOR" '
      ($families | split(",") | map(ascii_downcase)) as $wanted
      | [
          .[]
          | . as $device
          | ((.manufacturer // "") + " " + (.device // "") | ascii_downcase) as $label
          | ((.os_version // "0") | split(".")[0] | tonumber? // 0) as $major
          | select($major >= $minMajor)
          | select(any($wanted[]; . as $needle | $label | contains($needle)))
          | (.device + "-" + .os_version)
        ]
      | unique
      | .[:5]
    ' <<<"$DEVICES_JSON"
)"

DEVICE_COUNT="$(jq 'length' <<<"$SELECTED_DEVICES")"
if [[ "$DEVICE_COUNT" -lt 2 ]]; then
  echo "Could not resolve at least two supported OEM devices from BrowserStack." >&2
  echo "Requested families: $DEVICE_FAMILIES" >&2
  jq -r '.[] | [.manufacturer, .device, .os_version] | @tsv' <<<"$DEVICES_JSON" | head -100 >&2
  exit 3
fi

BUILD_PAYLOAD="$(jq -n \
  --arg app "$APP_URL" \
  --arg testSuite "$TEST_URL" \
  --arg project "$PROJECT_NAME" \
  --arg buildTag "$BUILD_TAG" \
  --argjson devices "$SELECTED_DEVICES" \
  '{app:$app,testSuite:$testSuite,devices:$devices,project:$project,buildTag:$buildTag}')"

BUILD_RESPONSE="$(curl --fail --silent --show-error \
  -u "$AUTH" \
  -H 'Content-Type: application/json' \
  -X POST "$API_ROOT/espresso/v2/build" \
  -d "$BUILD_PAYLOAD")"
BUILD_ID="$(jq -er '.build_id' <<<"$BUILD_RESPONSE")"

echo "BrowserStack build: $BUILD_ID"
echo "Selected devices: $(jq -r 'join(", ")' <<<"$SELECTED_DEVICES")"

for ((poll=1; poll<=MAX_POLLS; poll++)); do
  RESULT="$(curl --fail --silent --show-error \
    -u "$AUTH" \
    "$API_ROOT/espresso/v2/builds/$BUILD_ID")"
  STATUS="$(jq -r '(.status // .state // "unknown") | ascii_downcase' <<<"$RESULT")"
  echo "Poll $poll/$MAX_POLLS: $STATUS"

  case "$STATUS" in
    passed|done|completed)
      FAILED_SESSIONS="$(jq '[.. | objects | select((.status? // .state? // "") | ascii_downcase | IN("failed","error","timed_out","timeout"))] | length' <<<"$RESULT")"
      if [[ "$FAILED_SESSIONS" -gt 0 ]]; then
        jq . <<<"$RESULT"
        echo "One or more OEM real-device sessions failed." >&2
        exit 4
      fi
      jq . <<<"$RESULT" > browserstack-oem-result.json
      exit 0
      ;;
    failed|error|timed_out|timeout)
      jq . <<<"$RESULT"
      echo "OEM real-device build failed." >&2
      exit 5
      ;;
  esac

  sleep "$POLL_SECONDS"
done

echo "OEM real-device build did not finish before timeout." >&2
exit 6
