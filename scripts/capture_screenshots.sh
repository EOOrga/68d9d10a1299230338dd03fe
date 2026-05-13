#!/usr/bin/env bash
set -euo pipefail

package_name="${1:-com.taziggg100.drapierphilippe}"
apk_path="${2:-build/app/outputs/flutter-apk/app-debug.apk}"

if [[ ! -f "${apk_path}" ]]; then
  echo "APK not found: ${apk_path}" >&2
  exit 1
fi

device_count="$(adb devices | awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
if [[ "${device_count}" != "1" ]]; then
  echo "Expected exactly one connected emulator/device, found ${device_count}" >&2
  adb devices >&2
  exit 1
fi

adb install -r "${apk_path}" >/dev/null
adb shell monkey -p "${package_name}" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 4

size="$(adb shell wm size | awk '/Physical size:/ { print $3 }' | tr -d '\r')"
width="${size%x*}"
height="${size#*x}"

tap_percent() {
  local x_percent="$1"
  local y_percent="$2"
  adb shell input tap "$((width * x_percent / 100))" "$((height * y_percent / 100))"
  sleep "${3:-1}"
}

take_screen() {
  local name="$1"
  local foreground
  foreground="$(
    adb shell dumpsys window \
      | tr -d '\r' \
      | sed -nE 's/.*mCurrentFocus=Window\{[^ ]+ [^ ]+ ([^\/ ]+)\/.*/\1/p' \
      | tail -n 1
  )"
  if [[ -z "${foreground}" ]]; then
    foreground="$(
      adb shell dumpsys window \
        | tr -d '\r' \
        | sed -nE 's/.*mFocusedApp=ActivityRecord\{[^ ]+ [^ ]+ ([^\/ ]+)\/.*/\1/p' \
        | tail -n 1
    )"
  fi
  if [[ "${foreground}" != "${package_name}" ]]; then
    echo "Refusing screenshot ${name}; foreground package is ${foreground}" >&2
    exit 1
  fi
  adb exec-out screencap -p > "docs/screens/${name}.png"
}

mkdir -p docs/screens
rm -f docs/screens/*.png

take_screen 1
tap_percent 30 91 1
take_screen 2
tap_percent 50 91 1
take_screen 3
tap_percent 70 91 1
take_screen 4
tap_percent 90 91 1
take_screen 5

adb shell pm uninstall "${package_name}" >/dev/null || true
