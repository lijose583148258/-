#!/usr/bin/env bash
set -euo pipefail

artifact_dir="../artifacts"
drive_log="$artifact_dir/flutter-drive.log"
logcat_log="$artifact_dir/adb-logcat.log"
mkdir -p "$artifact_dir"

adb devices > "$artifact_dir/adb-devices.log"
flutter devices > "$artifact_dir/flutter-devices.log"
adb logcat -c

flutter drive \
  --no-pub \
  --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk \
  --driver integration_test/driver.dart \
  --target integration_test/app_launch_test.dart \
  -d emulator-5554 > "$drive_log" 2>&1 &
drive_pid=$!

cleanup_driver() {
  if kill -0 "$drive_pid" 2>/dev/null; then
    kill -TERM "$drive_pid" 2>/dev/null || true
    sleep 2
    kill -KILL "$drive_pid" 2>/dev/null || true
  fi
}
trap cleanup_driver EXIT

passed=false
timed_out=false
for _ in $(seq 1 300); do
  if grep -Fq "All tests passed!" "$drive_log"; then
    passed=true
    break
  fi
  if ! kill -0 "$drive_pid" 2>/dev/null; then
    break
  fi
  sleep 2
done

if [ "$passed" = true ]; then
  cleanup_driver
elif kill -0 "$drive_pid" 2>/dev/null; then
  timed_out=true
  cleanup_driver
fi

set +e
wait "$drive_pid" 2>/dev/null
process_status=$?
set -e
trap - EXIT

# Read the final buffered output after the process has exited.
if grep -Fq "All tests passed!" "$drive_log"; then
  status=0
elif [ "$timed_out" = true ]; then
  status=124
else
  status=$process_status
fi

adb logcat -d -v threadtime > "$logcat_log" || true

if [ "$status" -eq 0 ] && grep -Fq "Creating TextToSpeech after first Flutter method call" "$logcat_log"; then
  echo "Unexpected TTS initialization during cold-start smoke test"
  status=1
fi

cat "$drive_log"
exit "$status"
