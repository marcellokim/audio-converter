# Distribution and signing notes

## v1 assumptions
- Platform: macOS only
- Distribution: direct download outside the Mac App Store
- Sandbox: disabled for v1
- Signing goal: signed and notarized release builds
- P1 notice/compliance packaging remains a prerequisite before shipping any distributable

## Automated release lane
`scripts/release-sign-and-notarize.sh` now owns the repeatable post-build release lane for nested signing and notarization.

### What the script does
1. Stages the canonical `Contents/Resources/ThirdPartyNotices` bundle via `scripts/package-notice-bundle.sh`.
2. Verifies the built app bundle exists and contains the embedded helper executable at `Contents/Helpers/ffmpeg`.
3. Signs the nested vendored `ffmpeg` helper before the app bundle.
4. Re-signs `AudioConverter.app` with hardened runtime while avoiding accidental reuse of development-only build entitlements.
5. Runs `syspolicy_check notary-submission` before packaging when that tool is available on the release machine.
6. Packages the app into a notarization-submission zip.
7. Optionally submits the zip with `xcrun notarytool`, waits for completion, staples the ticket, then runs `syspolicy_check distribution` + `spctl` validation and re-packages the stapled app into a final distribution zip.

### Supported inputs
The script accepts either CLI flags or environment variables:
- `AUDIOCONVERTER_SIGNING_IDENTITY` — Developer ID Application identity for the app bundle
- `AUDIOCONVERTER_NESTED_SIGNING_IDENTITY` — optional override for the nested `ffmpeg` helper executable (defaults to the app identity)
- `AUDIOCONVERTER_APP_ENTITLEMENTS` — optional explicit entitlements plist to use for the app signature if the release build ever requires non-default distribution entitlements (defaults to `AudioConverter/Config/Release.entitlements`)
- `AUDIOCONVERTER_NOTARY_PROFILE` — `xcrun notarytool` keychain profile created with `xcrun notarytool store-credentials`
- `AUDIOCONVERTER_TEAM_ID` — optional team id for shared release machines / CI

### Rehearsal mode
Use rehearsal mode on any machine that can build the app, even if release credentials are not available yet. It stages the release notice bundle, validates the bundle layout, emits the notarization zip, and prints the exact commands that a full release run will execute.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project AudioConverter.xcodeproj -scheme AudioConverter \
  -configuration Release SYMROOT=build build

scripts/release-sign-and-notarize.sh \
  --mode rehearse \
  --app build/Release/AudioConverter.app
```

### Full signing + notarization run
Run the full lane only after the release-specific notice bundle is ready and the Apple signing/notarization credentials are available.

```bash
export AUDIOCONVERTER_SIGNING_IDENTITY="Developer ID Application: Example Corp (TEAMID1234)"
export AUDIOCONVERTER_NOTARY_PROFILE="AudioConverter-Notary"
export AUDIOCONVERTER_TEAM_ID="TEAMID1234"
# Optional only if the release app needs explicit non-default entitlements:
# export AUDIOCONVERTER_APP_ENTITLEMENTS="/absolute/path/to/Distribution.entitlements"

scripts/release-sign-and-notarize.sh \
  --mode run \
  --app build/Release/AudioConverter.app
```

### Outputs
By default the script writes release artifacts to `build/release-automation/`:
- `AudioConverter-for-notarization.zip`
- `AudioConverter-distribution.zip`
- `notarytool-submit.json` (full run only)

The script signs the app bundle in place. `AudioConverter-for-notarization.zip` is a submission-only artifact; `AudioConverter-distribution.zip` is the post-stapling direct-download zip. If you need to preserve an unsigned build for comparison, copy the bundle first and pass the copy to `--app`.

When `--skip-notarization` is used for local verification, the script emits `AudioConverter-distribution-UNNOTARIZED.zip` instead of the final distribution filename to avoid accidental publication of a non-notarized artifact.

### Why the helper path matters
Local release builds produced by Xcode on non-release machines can carry development-only signing state such as `com.apple.security.get-task-allow`, and `syspolicy_check` warns when Mach-O binaries live under `Contents/Resources/`. The release lane therefore:

- embeds FFmpeg under `Contents/Helpers/ffmpeg` inside the built app bundle, and
- re-signs the app with the repo-tracked default release entitlements policy unless an explicit distribution entitlements plist is supplied.

## Verified local commands
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /opt/homebrew/bin/xcodegen generate`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project AudioConverter.xcodeproj -scheme AudioConverter -configuration Release SYMROOT=build build`
- `bash -n scripts/release-sign-and-notarize.sh`
- `scripts/release-sign-and-notarize.sh --mode rehearse --app build/Release/AudioConverter.app`
- `scripts/release-sign-and-notarize.sh --mode run --app build/Release/AudioConverter.app --signing-identity - --nested-signing-identity - --skip-notarization`

## Related release documents
- `docs/release-checklist.md` — ship checklist for pre-release validation, signing, notarization, and manual QA.
- `docs/ffmpeg-licensing.md` — licensing gate for the vendored FFmpeg artifact.
