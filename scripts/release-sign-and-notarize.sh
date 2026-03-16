#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/release-sign-and-notarize.sh [options]

Automates the post-build macOS release lane for AudioConverter:
1. verify the built app bundle contains the vendored ffmpeg binary
2. sign the nested ffmpeg executable
3. re-sign the app bundle with hardened runtime
4. package the app for notarization
5. optionally submit with notarytool, staple, and validate Gatekeeper

Options:
  --mode rehearse|run          Default: rehearse
  --app PATH                   Default: build/Release/AudioConverter.app
  --output-dir PATH            Default: build/release-automation
  --signing-identity NAME      Overrides AUDIOCONVERTER_SIGNING_IDENTITY
  --nested-signing-identity N  Overrides AUDIOCONVERTER_NESTED_SIGNING_IDENTITY
  --notary-profile PROFILE     Overrides AUDIOCONVERTER_NOTARY_PROFILE
  --team-id TEAMID             Overrides AUDIOCONVERTER_TEAM_ID
  --skip-notarization          Sign + package, but skip notarytool/stapler
  --help                       Show this help

Environment:
  AUDIOCONVERTER_SIGNING_IDENTITY
  AUDIOCONVERTER_NESTED_SIGNING_IDENTITY (defaults to AUDIOCONVERTER_SIGNING_IDENTITY)
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
embedded_ffmpeg_path="$app_path/Contents/Resources/ffmpeg/ffmpeg"
zip_path="$output_dir/${app_stem}-for-notarization.zip"
notary_log_path="$output_dir/notarytool-submit.json"

ensure_prerequisites() {
  require_command xcrun
  require_command codesign
  require_command ditto
  require_command spctl
  require_directory "$app_path"
  require_file "$embedded_ffmpeg_path"
  mkdir -p "$output_dir"
  require_xcrun_tool stapler

  if [ "$mode" = "run" ] && [ "$skip_notarization" -eq 0 ]; then
    require_xcrun_tool notarytool
    require_value "AUDIOCONVERTER_NOTARY_PROFILE / --notary-profile" "$notary_profile"
  fi

  if [ "$mode" = "run" ]; then
    require_value "AUDIOCONVERTER_SIGNING_IDENTITY / --signing-identity" "$signing_identity"
    require_value "AUDIOCONVERTER_NESTED_SIGNING_IDENTITY / --nested-signing-identity" "$nested_signing_identity"
  fi
}

package_for_notarization() {
  rm -f "$zip_path"
  run_command ditto -c -k --keepParent "$app_path" "$zip_path"
}

sign_nested_executable() {
  run_command \
    codesign \
    --force \
    --timestamp \
    --options runtime \
    --sign "$nested_signing_identity" \
    "$embedded_ffmpeg_path"

  run_command codesign --verify --strict --verbose=2 "$embedded_ffmpeg_path"
}

sign_app_bundle() {
  run_command \
    codesign \
    --force \
    --timestamp \
    --options runtime \
    --sign "$signing_identity" \
    --preserve-metadata=identifier,entitlements \
    "$app_path"

  run_command codesign --verify --deep --strict --verbose=2 "$app_path"
}

submit_for_notarization() {
  local args=(
    xcrun notarytool submit "$zip_path"
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
  run_command spctl -a -vv "$app_path"
}

print_rehearsal_summary() {
  echo "[rehearse] Verified app bundle layout and packaged a notarization zip."
  echo "[rehearse] App bundle: $app_path"
  echo "[rehearse] Nested executable: $embedded_ffmpeg_path"
  echo "[rehearse] Notarization zip: $zip_path"
  echo "[rehearse] Full run command plan:"
  print_command codesign --force --timestamp --options runtime --sign "${nested_signing_identity:-<nested-signing-identity>}" "$embedded_ffmpeg_path"
  print_command codesign --force --timestamp --options runtime --sign "${signing_identity:-<signing-identity>}" --preserve-metadata=identifier,entitlements "$app_path"
  print_command codesign --verify --deep --strict --verbose=2 "$app_path"

  if [ "$skip_notarization" -eq 1 ]; then
    echo "[rehearse] Notarization/stapling explicitly skipped."
    return
  fi

  if [ -n "$notary_profile" ]; then
    if [ -n "$team_id" ]; then
      print_command xcrun notarytool submit "$zip_path" --keychain-profile "$notary_profile" --team-id "$team_id" --wait --output-format json
    else
      print_command xcrun notarytool submit "$zip_path" --keychain-profile "$notary_profile" --wait --output-format json
    fi
    print_command xcrun stapler staple "$app_path"
    print_command xcrun stapler validate "$app_path"
    print_command spctl -a -vv "$app_path"
  else
    echo "[rehearse] Set AUDIOCONVERTER_NOTARY_PROFILE (or --notary-profile) to enable full notarization submission."
  fi
}

ensure_prerequisites
package_for_notarization

if [ "$mode" = "rehearse" ]; then
  print_rehearsal_summary
  exit 0
fi

sign_nested_executable
sign_app_bundle
package_for_notarization

if [ "$skip_notarization" -eq 0 ]; then
  submit_for_notarization
  staple_and_validate
else
  echo "[run] Skipping notarization/stapling by request. Signed app bundle is ready at $app_path"
fi

echo "[run] Release automation completed."
echo "[run] App bundle: $app_path"
echo "[run] Notarization zip: $zip_path"
if [ "$skip_notarization" -eq 0 ]; then
  echo "[run] Notary log: $notary_log_path"
fi
