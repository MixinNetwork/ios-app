#!/bin/bash
set -euo pipefail

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
SUPPORTING_DIR="$REPO_ROOT/Mixin/Supporting Files"

restore_plist() {
  local var_name="$1"
  local var_value="$2"
  local dest_path="$3"

  if [ -z "$var_value" ]; then
    echo "error: $var_name is not set" >&2
    exit 1
  fi

  printf '%s' "$var_value" | tr -d '[:space:]' | base64 --decode > "$dest_path"
  plutil -lint "$dest_path" >/dev/null
  echo "Restored $dest_path"
}

restore_plist \
  "GOOGLE_SERVICE_INFO_PLIST_BASE64" \
  "${GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" \
  "$SUPPORTING_DIR/GoogleService-Info.plist"

restore_plist \
  "MIXIN_KEYS_PLIST_BASE64" \
  "${MIXIN_KEYS_PLIST_BASE64:-}" \
  "$SUPPORTING_DIR/Mixin-Keys.plist"

if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  echo "Setting build number to CI_BUILD_NUMBER=$CI_BUILD_NUMBER"
  cd "$REPO_ROOT"
  xcrun agvtool new-version -all "$CI_BUILD_NUMBER"
fi

# Allow Swift Package Build Tool Plugins (R.swift / LicensePlist) and Macros in CI
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
