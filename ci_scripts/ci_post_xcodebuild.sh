#!/bin/bash
set +x
set -euo pipefail
shopt -s nullglob

if [[ "${CI_XCODEBUILD_ACTION:-}" != archive || "${CI_XCODEBUILD_EXIT_CODE:-}" != 0 ]]; then
  exit 0
fi

archive_path="${CI_ARCHIVE_PATH:-}"
if [[ -z "$archive_path" || ! -d "$archive_path" ]]; then
  echo "error: Xcode Cloud did not provide an archive at CI_ARCHIVE_PATH." >&2
  exit 1
fi

dsym_directory="$archive_path/dSYMs"
dsyms=("$dsym_directory"/*.dSYM)
if (( ${#dsyms[@]} == 0 )); then
  echo "error: No dSYMs found in $dsym_directory." >&2
  exit 1
fi

upload_crashlytics() {
  if [[ -z "${CI_DERIVED_DATA_PATH:-}" ]]; then
    echo "error: Xcode Cloud did not provide CI_DERIVED_DATA_PATH." >&2
    return 1
  fi

  local uploader="$CI_DERIVED_DATA_PATH/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"
  local plists=("$archive_path"/Products/Applications/*.app/GoogleService-Info.plist)
  if [[ ! -x "$uploader" ]]; then
    echo "error: Firebase Crashlytics uploader not found at $uploader." >&2
    return 1
  fi
  if (( ${#plists[@]} != 1 )); then
    echo "error: Expected exactly one GoogleService-Info.plist in the archived app." >&2
    return 1
  fi

  local delay
  for delay in 0 5 15 30; do
    if (( delay > 0 )); then
      echo "Retrying Crashlytics symbol upload in ${delay}s."
      sleep "$delay"
    fi
    if "$uploader" -gsp "${plists[0]}" -p ios "$dsym_directory"; then
      return 0
    fi
  done
  return 1
}

upload_bugsnag() (
  if [[ -z "${BUGSNAG_API_KEY:-}" ]]; then
    echo "error: Set BUGSNAG_API_KEY as a secret in the Xcode Cloud workflow." >&2
    return 1
  fi

  local temp_directory
  temp_directory="$(mktemp -d)" || return 1
  trap 'rm -rf "$temp_directory"' EXIT

  local cli="$temp_directory/bugsnag-cli"
  local version="v3.10.7"
  local expected_sha256="4b9ac73d411cb36feb85ff6db71b136124f60b2cd7352a678581f79629ca2b4e"
  curl --fail --silent --show-error --location \
    --retry 3 --retry-all-errors --connect-timeout 15 --max-time 60 \
    --output "$cli" \
    "https://github.com/bugsnag/bugsnag-cli/releases/download/$version/arm64-macos-bugsnag-cli" || return 1
  if ! printf '%s  %s\n' "$expected_sha256" "$cli" | shasum -a 256 -c -; then
    echo "error: SHA-256 verification failed for BugSnag CLI $version." >&2
    return 1
  fi
  chmod +x "$cli" || return 1

  # Redact the key even if the CLI includes it in a diagnostic.
  "$cli" upload xcode-archive --api-key="$BUGSNAG_API_KEY" --retries 3 "$archive_path" 2>&1 |
    while IFS= read -r line || [[ -n "$line" ]]; do
      printf '%s\n' "${line//"$BUGSNAG_API_KEY"/[REDACTED]}"
    done
)

status=0
if ! upload_crashlytics; then
  echo "error: Firebase Crashlytics symbol upload failed." >&2
  status=1
fi
if ! upload_bugsnag; then
  echo "error: Bugsnag symbol upload failed." >&2
  status=1
fi
exit "$status"
