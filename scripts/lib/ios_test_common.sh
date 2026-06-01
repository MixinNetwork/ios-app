#!/usr/bin/env bash

set -euo pipefail

IOS_TEST_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_TEST_REPO_ROOT="$(cd "$IOS_TEST_COMMON_DIR/../.." && pwd)"

IOS_TEST_WORKSPACE="${IOS_TEST_WORKSPACE:-Mixin.xcworkspace}"
IOS_TEST_SCHEME="${IOS_TEST_SCHEME:-Mixin}"
IOS_TEST_RESULT_ROOT="${IOS_TEST_RESULT_ROOT:-TestResults}"
IOS_TEST_DOWNLOAD_PLATFORM="${IOS_TEST_DOWNLOAD_PLATFORM:-1}"

prepare_local_configuration_files() {
  local supporting_files_dir="$IOS_TEST_REPO_ROOT/Mixin/Supporting Files"
  local mixin_keys_path="$supporting_files_dir/Mixin-Keys.plist"
  local google_service_path="$supporting_files_dir/GoogleService-Info.plist"

  mkdir -p "$supporting_files_dir"

  local wallet_connect_key=""
  if [[ -f "$mixin_keys_path" ]]; then
    wallet_connect_key="$(/usr/libexec/PlistBuddy -c "Print WalletConnect" "$mixin_keys_path" 2>/dev/null || true)"
  fi

  if [[ ! -f "$mixin_keys_path" || "$wallet_connect_key" == "ui-test-placeholder" ]]; then
    cat > "$mixin_keys_path" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>AppsFlyer</key>
  <string>ui-test-placeholder</string>
  <key>WalletConnect</key>
  <string>ui-test-placeholder</string>
</dict>
</plist>
PLIST
  fi

  local google_api_key=""
  if [[ -f "$google_service_path" ]]; then
    google_api_key="$(/usr/libexec/PlistBuddy -c "Print API_KEY" "$google_service_path" 2>/dev/null || true)"
  fi

  if [[ ! -f "$google_service_path" || "$google_api_key" == "ui-test-placeholder" ]]; then
    cat > "$google_service_path" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>API_KEY</key>
  <string>AIzaSyDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD</string>
  <key>BUNDLE_ID</key>
  <string>one.mixin.messenger</string>
  <key>GCM_SENDER_ID</key>
  <string>000000000000</string>
  <key>GOOGLE_APP_ID</key>
  <string>1:000000000000:ios:0000000000000000000000</string>
  <key>PROJECT_ID</key>
  <string>ui-test-placeholder</string>
</dict>
</plist>
PLIST
  fi
}

install_cocoapods_dependencies_if_needed() {
  if [[ "${IOS_TEST_SKIP_POD_INSTALL:-0}" == "1" ]]; then
    return
  fi

  if ! command -v pod >/dev/null 2>&1; then
    echo "error: CocoaPods is required. Install it, then rerun this script." >&2
    exit 1
  fi

  if [[ ! -f "$IOS_TEST_REPO_ROOT/Pods/Manifest.lock" ]] ||
    ! cmp -s "$IOS_TEST_REPO_ROOT/Podfile.lock" "$IOS_TEST_REPO_ROOT/Pods/Manifest.lock"; then
    (cd "$IOS_TEST_REPO_ROOT" && pod install)
  fi
}

latest_ios_runtime_id() {
  python3 <<'PY'
import json
import re
import subprocess

output = subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "available", "-j"])
runtimes = json.loads(output).get("runtimes", [])
ios_runtimes = [
    runtime for runtime in runtimes
    if runtime.get("platform") == "iOS" and runtime.get("isAvailable")
]

def version_key(runtime):
    return tuple(int(part) for part in re.findall(r"\d+", runtime.get("version", "")))

if ios_runtimes:
    print(sorted(ios_runtimes, key=version_key, reverse=True)[0]["identifier"])
PY
}

select_or_create_ios_device_id() {
  local runtime_id="$1"
  local device_id

  if [[ -n "${IOS_TEST_DESTINATION_ID:-}" ]]; then
    echo "$IOS_TEST_DESTINATION_ID"
    return
  fi

  device_id="$(RUNTIME_ID="$runtime_id" IOS_TEST_DEVICE_NAME="${IOS_TEST_DEVICE_NAME:-iPhone 16e}" python3 <<'PY'
import json
import os
import subprocess

runtime_id = os.environ["RUNTIME_ID"]
preferred_name = os.environ["IOS_TEST_DEVICE_NAME"]
output = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
devices = json.loads(output).get("devices", {}).get(runtime_id, [])

for preferred in (preferred_name, "iPhone 16e", "iPhone SE (3rd generation)"):
    for device in devices:
        if device.get("isAvailable") and device.get("name") == preferred:
            print(device["udid"])
            raise SystemExit

for device in devices:
    if device.get("isAvailable") and ".iPhone-" in device.get("deviceTypeIdentifier", ""):
        print(device["udid"])
        raise SystemExit
PY
)"

  if [[ -n "$device_id" ]]; then
    echo "$device_id"
    return
  fi

  local device_type
  device_type="$(RUNTIME_ID="$runtime_id" IOS_TEST_DEVICE_NAME="${IOS_TEST_DEVICE_NAME:-iPhone 16e}" python3 <<'PY'
import json
import os
import subprocess

runtime_id = os.environ["RUNTIME_ID"]
preferred_name = os.environ["IOS_TEST_DEVICE_NAME"]
output = subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "available", "-j"])
runtime = next(
    runtime for runtime in json.loads(output).get("runtimes", [])
    if runtime.get("identifier") == runtime_id
)
device_types = runtime.get("supportedDeviceTypes", [])

for preferred in (preferred_name, "iPhone 16e", "iPhone SE (3rd generation)"):
    for device_type in device_types:
        if device_type.get("name") == preferred:
            print(device_type["identifier"])
            raise SystemExit

for device_type in device_types:
    if device_type.get("productFamily") == "iPhone":
        print(device_type["identifier"])
        raise SystemExit
PY
)"

  if [[ -z "$device_type" ]]; then
    echo "error: No available iPhone simulator device type found." >&2
    exit 1
  fi

  xcrun simctl create "Mixin iOS Tests" "$device_type" "$runtime_id"
}

ios_test_destination() {
  if [[ -n "${IOS_TEST_DESTINATION:-}" ]]; then
    echo "$IOS_TEST_DESTINATION"
    return
  fi

  local runtime_id
  runtime_id="$(latest_ios_runtime_id)"
  if [[ -z "$runtime_id" && "$IOS_TEST_DOWNLOAD_PLATFORM" == "1" ]]; then
    xcodebuild -downloadPlatform iOS -architectureVariant arm64 >&2
    runtime_id="$(latest_ios_runtime_id)"
  fi

  if [[ -z "$runtime_id" ]]; then
    echo "error: No available iOS simulator runtime found." >&2
    exit 1
  fi

  local device_id
  device_id="$(select_or_create_ios_device_id "$runtime_id")"
  xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$device_id" -b >&2

  echo "id=$device_id"
}

result_bundle_name_for_mode() {
  case "$1" in
    all)
      echo "iOS-All.xcresult"
      ;;
    unit)
      echo "iOS-Unit.xcresult"
      ;;
    ui)
      echo "iOS-UI.xcresult"
      ;;
    *)
      echo "error: Unsupported iOS test mode: $1" >&2
      exit 1
      ;;
  esac
}

run_ios_tests() {
  local mode="$1"
  shift

  cd "$IOS_TEST_REPO_ROOT"

  prepare_local_configuration_files
  install_cocoapods_dependencies_if_needed

  local destination
  destination="$(ios_test_destination)"

  mkdir -p "$IOS_TEST_RESULT_ROOT"
  local result_bundle_path="$IOS_TEST_RESULT_ROOT/$(result_bundle_name_for_mode "$mode")"
  rm -rf "$result_bundle_path"

  local args=(
    test
    -workspace "$IOS_TEST_WORKSPACE"
    -scheme "$IOS_TEST_SCHEME"
    -destination "$destination"
    -skipPackagePluginValidation
    -resultBundlePath "$result_bundle_path"
  )

  case "$mode" in
    all)
      ;;
    unit)
      args+=("-only-testing:MixinTests")
      ;;
    ui)
      args+=("-only-testing:MixinUITests")
      ;;
    *)
      echo "error: Unsupported iOS test mode: $mode" >&2
      exit 1
      ;;
  esac

  xcodebuild "${args[@]}" "$@"
}
