#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/release-sign-and-notarize.sh [options]

Automates the post-build macOS release lane for AudioConverter:
1. stage the canonical `ThirdPartyNotices` bundle into the app
2. verify the built app bundle contains the vendored ffmpeg helper executable
3. sign the nested ffmpeg helper
4. re-sign the app bundle with hardened runtime and distribution-safe entitlements
5. run local notarization-readiness checks when available
6. package the app for notarization submission
7. optionally submit with notarytool, staple, validate, and re-package the stapled app for distribution

Options:
  --mode rehearse|run          Default: rehearse
  --app PATH                   Default: build/Release/AudioConverter.app
  --output-dir PATH            Default: build/release-automation
  --signing-identity NAME      Overrides AUDIOCONVERTER_SIGNING_IDENTITY
  --nested-signing-identity N  Overrides AUDIOCONVERTER_NESTED_SIGNING_IDENTITY
  --app-entitlements PATH      Optional explicit entitlements plist for the app
  --notary-profile PROFILE     Overrides AUDIOCONVERTER_NOTARY_PROFILE
  --team-id TEAMID             Overrides AUDIOCONVERTER_TEAM_ID
  --skip-notarization          Sign + package, but skip notarytool/stapler
  --help                       Show this help

Environment:
  AUDIOCONVERTER_SIGNING_IDENTITY
  AUDIOCONVERTER_NESTED_SIGNING_IDENTITY (defaults to AUDIOCONVERTER_SIGNING_IDENTITY)
  AUDIOCONVERTER_APP_ENTITLEMENTS (optional explicit entitlements plist for app signing)
  AUDIOCONVERTER_NOTARY_PROFILE (xcrun notarytool keychain profile)
  AUDIOCONVERTER_TEAM_ID
USAGE
}

fail() {
  echo "error: $*" >&2
  exit 1
}

print_command() {
  local rendered=()
  local arg
  for arg in "$@"; do
    rendered+=("$(printf '%q' "$arg")")
  done
  printf '+ %s\n' "${rendered[*]}"
}

run_command() {
  print_command "$@"
  "$@"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_xcrun_tool() {
  xcrun --find "$1" >/dev/null 2>&1 || fail "required Xcode tool not found via xcrun: $1"
}

require_file() {
  [ -f "$1" ] || fail "required file not found: $1"
}

require_directory() {
  [ -d "$1" ] || fail "required directory not found: $1"
}

require_value() {
  [ -n "$2" ] || fail "$1 is required for this mode"
}

mode="rehearse"
app_path="build/Release/AudioConverter.app"
output_dir="build/release-automation"
signing_identity="${AUDIOCONVERTER_SIGNING_IDENTITY:-}"
nested_signing_identity="${AUDIOCONVERTER_NESTED_SIGNING_IDENTITY:-}"
app_entitlements="${AUDIOCONVERTER_APP_ENTITLEMENTS:-}"
notary_profile="${AUDIOCONVERTER_NOTARY_PROFILE:-}"
team_id="${AUDIOCONVERTER_TEAM_ID:-}"
skip_notarization=0

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)
      [ $# -ge 2 ] || fail "missing value for $1"
      mode="$2"
      shift 2
      ;;
    --app)
      [ $# -ge 2 ] || fail "missing value for $1"
      app_path="$2"
      shift 2
      ;;
    --output-dir)
      [ $# -ge 2 ] || fail "missing value for $1"
      output_dir="$2"
      shift 2
      ;;
    --signing-identity)
      [ $# -ge 2 ] || fail "missing value for $1"
      signing_identity="$2"
      shift 2
      ;;
    --nested-signing-identity)
      [ $# -ge 2 ] || fail "missing value for $1"
      nested_signing_identity="$2"
      shift 2
      ;;
    --app-entitlements)
      [ $# -ge 2 ] || fail "missing value for $1"
      app_entitlements="$2"
      shift 2
      ;;
    --notary-profile)
      [ $# -ge 2 ] || fail "missing value for $1"
      notary_profile="$2"
      shift 2
      ;;
    --team-id)
      [ $# -ge 2 ] || fail "missing value for $1"
      team_id="$2"
      shift 2
      ;;
    --skip-notarization)
      skip_notarization=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

case "$mode" in
  rehearse|run) ;;
  *) fail "unsupported mode: $mode (expected rehearse or run)" ;;
esac

if [ -z "$nested_signing_identity" ]; then
  nested_signing_identity="$signing_identity"
fi

app_path="${app_path%/}"
app_name="$(basename "$app_path")"
app_stem="${app_name%.app}"
embedded_ffmpeg_path="$app_path/Contents/Helpers/ffmpeg"
legacy_embedded_ffmpeg_path="$app_path/Contents/Resources/ffmpeg/ffmpeg"
notice_bundle_root="$app_path/Contents/Resources/ThirdPartyNotices"
submission_zip_path="$output_dir/${app_stem}-for-notarization.zip"
distribution_zip_path="$output_dir/${app_stem}-distribution.zip"
unnotarized_distribution_zip_path="$output_dir/${app_stem}-distribution-UNNOTARIZED.zip"
notary_log_path="$output_dir/notarytool-submit.json"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
package_notice_script="$repo_root/scripts/package-notice-bundle.sh"
default_release_entitlements="$repo_root/AudioConverter/Config/Release.entitlements"

if [ -z "$app_entitlements" ]; then
  app_entitlements="$default_release_entitlements"
fi

ensure_prerequisites() {
  require_command xcrun
  require_command codesign
  require_command ditto
  require_command diff
  require_command plutil
  require_command spctl
  require_command bash
  require_directory "$app_path"
  require_file "$package_notice_script"
  mkdir -p "$output_dir"
  require_xcrun_tool stapler

  require_file "$app_entitlements"

  if [ "$mode" = "run" ] && [ "$skip_notarization" -eq 0 ]; then
    require_xcrun_tool notarytool
    require_value "AUDIOCONVERTER_NOTARY_PROFILE / --notary-profile" "$notary_profile"
  fi

  if [ "$mode" = "run" ]; then
    require_value "AUDIOCONVERTER_SIGNING_IDENTITY / --signing-identity" "$signing_identity"
    require_value "AUDIOCONVERTER_NESTED_SIGNING_IDENTITY / --nested-signing-identity" "$nested_signing_identity"
  fi
}

assert_release_entitlements_match_baseline() {
  if [ "$app_entitlements" = "$default_release_entitlements" ]; then
    return
  fi

  if ! diff -u \
    <(plutil -convert xml1 -o - "$default_release_entitlements") \
    <(plutil -convert xml1 -o - "$app_entitlements") >/dev/null; then
    fail "app entitlements must match the approved release baseline at $default_release_entitlements"
  fi
}

verify_bundle_layout() {
  require_file "$embedded_ffmpeg_path"

  if [ -e "$legacy_embedded_ffmpeg_path" ]; then
    fail "release app still embeds ffmpeg under Contents/Resources; rebuild after updating the embed script"
  fi
}

stage_notice_bundle() {
  run_command "$package_notice_script" "$app_path"
  require_directory "$notice_bundle_root"
  require_file "$notice_bundle_root/NOTICE-MANIFEST.txt"
  require_file "$notice_bundle_root/NOTICE-MANIFEST.sha256"
}

package_for_notarization() {
  rm -f "$submission_zip_path"
  run_command ditto -c -k --keepParent "$app_path" "$submission_zip_path"
}

package_for_distribution() {
  rm -f "$distribution_zip_path"
  run_command ditto -c -k --keepParent "$app_path" "$distribution_zip_path"
}

package_unnotarized_distribution() {
  rm -f "$unnotarized_distribution_zip_path"
  run_command ditto -c -k --keepParent "$app_path" "$unnotarized_distribution_zip_path"
}

sign_nested_executable() {
  local args=(
    codesign
    --force
    --sign "$nested_signing_identity"
  )

  if [ "$nested_signing_identity" != "-" ]; then
    args+=(--timestamp)
  fi

  args+=("$embedded_ffmpeg_path")

  run_command "${args[@]}"

  run_command codesign --verify --strict --verbose=2 "$embedded_ffmpeg_path"
}

sign_app_bundle() {
  local args=(
    codesign
    --force
    --options runtime
    --sign "$signing_identity"
    --entitlements "$app_entitlements"
  )

  if [ "$signing_identity" != "-" ]; then
    args+=(--timestamp)
  fi

  args+=("$app_path")

  run_command "${args[@]}"
  run_command codesign --verify --deep --strict --verbose=2 "$app_path"
}

assert_no_development_entitlements() {
  local entitlements
  entitlements="$(codesign -d --entitlements :- "$app_path" 2>&1 || true)"

  if printf '%s' "$entitlements" | grep -q "com.apple.security.get-task-allow"; then
    fail "signed app still contains com.apple.security.get-task-allow; supply a distribution entitlements plist or sign without preserving build entitlements"
  fi
}

run_syspolicy_check_if_available() {
  local subcommand="$1"

  if ! command -v syspolicy_check >/dev/null 2>&1; then
    echo "[info] syspolicy_check is unavailable on this machine; skipping $subcommand preflight."
    return
  fi

  run_command syspolicy_check "$subcommand" "$app_path"
}

should_run_syspolicy_preflight() {
  [ "$signing_identity" != "-" ]
}

submit_for_notarization() {
  local args=(
    xcrun notarytool submit "$submission_zip_path"
    --keychain-profile "$notary_profile"
    --wait
    --output-format json
  )

  if [ -n "$team_id" ]; then
    args+=(--team-id "$team_id")
  fi

  print_command "${args[@]}"
  "${args[@]}" | tee "$notary_log_path"
}

staple_and_validate() {
  run_command xcrun stapler staple "$app_path"
  run_command xcrun stapler validate "$app_path"
  run_syspolicy_check_if_available distribution
  run_command spctl -a -vv "$app_path"
}

print_rehearsal_summary() {
  echo "[rehearse] Staged ThirdPartyNotices, verified app bundle layout, and packaged a notarization-submission zip."
  echo "[rehearse] App bundle: $app_path"
  echo "[rehearse] Nested executable: $embedded_ffmpeg_path"
  echo "[rehearse] Notice bundle: $notice_bundle_root"
  echo "[rehearse] Notarization submission zip: $submission_zip_path"
  echo "[rehearse] Distribution zip (created after stapling in full runs): $distribution_zip_path"
  echo "[rehearse] Full run command plan:"
  print_command "$package_notice_script" "$app_path"
  if [ "${nested_signing_identity:-}" = "-" ]; then
    print_command codesign --force --sign "${nested_signing_identity:-<nested-signing-identity>}" "$embedded_ffmpeg_path"
  else
    print_command codesign --force --timestamp --sign "${nested_signing_identity:-<nested-signing-identity>}" "$embedded_ffmpeg_path"
  fi
  if [ "${signing_identity:-}" = "-" ]; then
    print_command codesign --force --options runtime --sign "${signing_identity:-<signing-identity>}" --entitlements "$app_entitlements" "$app_path"
  else
    print_command codesign --force --timestamp --options runtime --sign "${signing_identity:-<signing-identity>}" --entitlements "$app_entitlements" "$app_path"
  fi
  print_command codesign --verify --deep --strict --verbose=2 "$app_path"
  print_command syspolicy_check notary-submission "$app_path"
  print_command ditto -c -k --keepParent "$app_path" "$submission_zip_path"

  if [ "$skip_notarization" -eq 1 ]; then
    echo "[rehearse] Notarization/stapling explicitly skipped."
    return
  fi

  if [ -n "$notary_profile" ]; then
    if [ -n "$team_id" ]; then
      print_command xcrun notarytool submit "$submission_zip_path" --keychain-profile "$notary_profile" --team-id "$team_id" --wait --output-format json
    else
      print_command xcrun notarytool submit "$submission_zip_path" --keychain-profile "$notary_profile" --wait --output-format json
    fi
    print_command xcrun stapler staple "$app_path"
    print_command xcrun stapler validate "$app_path"
    print_command syspolicy_check distribution "$app_path"
    print_command spctl -a -vv "$app_path"
    print_command ditto -c -k --keepParent "$app_path" "$distribution_zip_path"
  else
    echo "[rehearse] Set AUDIOCONVERTER_NOTARY_PROFILE (or --notary-profile) to enable full notarization submission."
  fi
}

ensure_prerequisites
assert_release_entitlements_match_baseline
stage_notice_bundle
verify_bundle_layout
package_for_notarization

if [ "$mode" = "rehearse" ]; then
  print_rehearsal_summary
  exit 0
fi

sign_nested_executable
sign_app_bundle
assert_no_development_entitlements
if should_run_syspolicy_preflight; then
  run_syspolicy_check_if_available notary-submission
else
  echo "[run] Skipping syspolicy notarization-readiness preflight for ad-hoc signing identity '-'."
fi
package_for_notarization

if [ "$skip_notarization" -eq 0 ]; then
  submit_for_notarization
  staple_and_validate
  package_for_distribution
else
  package_unnotarized_distribution
  echo "[run] Skipping notarization/stapling by request. Created non-release verification artifact: $unnotarized_distribution_zip_path"
fi

echo "[run] Release automation completed."
echo "[run] App bundle: $app_path"
echo "[run] Notarization submission zip: $submission_zip_path"
if [ "$skip_notarization" -eq 0 ]; then
  echo "[run] Distribution zip: $distribution_zip_path"
  echo "[run] Notary log: $notary_log_path"
else
  echo "[run] Verification zip: $unnotarized_distribution_zip_path"
fi
