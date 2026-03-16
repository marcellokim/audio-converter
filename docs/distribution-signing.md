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
2. Verifies the built app bundle exists and still contains `Contents/Resources/ffmpeg/ffmpeg`.
3. Signs the nested vendored `ffmpeg` executable before the app bundle.
4. Re-signs `AudioConverter.app` with hardened runtime preserved.
5. Packages the app into a notarization zip.
6. Optionally submits the zip with `xcrun notarytool`, waits for completion, staples the ticket, and runs `spctl` validation.

### Supported inputs
The script accepts either CLI flags or environment variables:
- `AUDIOCONVERTER_SIGNING_IDENTITY` — Developer ID Application identity for the app bundle
- `AUDIOCONVERTER_NESTED_SIGNING_IDENTITY` — optional override for the nested `ffmpeg` executable (defaults to the app identity)
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

scripts/release-sign-and-notarize.sh \
  --mode run \
  --app build/Release/AudioConverter.app
```

### Outputs
By default the script writes release artifacts to `build/release-automation/`:
- `AudioConverter-for-notarization.zip`
- `notarytool-submit.json` (full run only)

The script signs the app bundle in place. If you need to preserve an unsigned build for comparison, copy the bundle first and pass the copy to `--app`.

## Verified local commands
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /opt/homebrew/bin/xcodegen generate`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project AudioConverter.xcodeproj -scheme AudioConverter -configuration Release SYMROOT=build build`
- `bash -n scripts/release-sign-and-notarize.sh`
- `scripts/release-sign-and-notarize.sh --mode rehearse --app build/Release/AudioConverter.app`

## Related release documents
- `docs/release-checklist.md` — ship checklist for pre-release validation, signing, notarization, and manual QA.
- `docs/ffmpeg-licensing.md` — licensing gate for the vendored FFmpeg artifact.
