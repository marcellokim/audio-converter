# Release checklist

## Scope for v1 direct distribution
- macOS-only release target (`arm64`)
- Direct download outside the Mac App Store
- App Sandbox disabled for v1
- Signed and notarized app bundle required before distribution

## Pre-release artifact checks
1. Confirm `AudioConverter/Resources/ffmpeg/ffmpeg` matches the approved vendored artifact recorded in `docs/ffmpeg-provenance.md`.
2. Recompute the vendored binary SHA256 and confirm it matches `docs/ffmpeg-provenance.md`.
3. Capture `-version`, `-buildconf`, `-encoders`, and `-muxers` output from the vendored binary and confirm the published provenance/licensing notes still match the shipped artifact.
4. Confirm the licensing package described in `docs/ffmpeg-licensing.md` is included with the release artifact, including any notices/source instructions required by linked external libraries.
5. Regenerate the Xcode project from `project.yml` after any build-script change.
6. Build a Release app bundle with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project AudioConverter.xcodeproj -scheme AudioConverter -configuration Release SYMROOT=build build`.
7. Run the real-FFmpeg integration test with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project AudioConverter.xcodeproj -scheme AudioConverter -destination 'platform=macOS' -only-testing:AudioConverterTests/RealFFmpegIntegrationTests test`.
8. Run the full test suite with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project AudioConverter.xcodeproj -scheme AudioConverter -destination 'platform=macOS' test`.

## Signing + notarization
1. Run the scripted rehearsal path to verify the built bundle contains the nested vendored `ffmpeg` executable and to generate the notarization zip:
   ```bash
   scripts/release-sign-and-notarize.sh --mode rehearse --app build/Release/AudioConverter.app
   ```
2. Export the Developer ID identity and `notarytool` keychain profile for the release machine:
   ```bash
   export AUDIOCONVERTER_SIGNING_IDENTITY="Developer ID Application: Example Corp (TEAMID1234)"
   export AUDIOCONVERTER_NOTARY_PROFILE="AudioConverter-Notary"
   export AUDIOCONVERTER_TEAM_ID="TEAMID1234"
   ```
3. Run the full signing/notarization lane:
   ```bash
   scripts/release-sign-and-notarize.sh --mode run --app build/Release/AudioConverter.app
   ```
4. Inspect `build/release-automation/notarytool-submit.json` and preserve it with the release notes/build metadata.
5. Verify Gatekeeper acceptance on a clean macOS machine after stapling.

## Manual QA before shipping
- Launch the app and confirm startup self-check succeeds with the bundled ffmpeg binary.
- Convert representative inputs into each v1 output format.
- Confirm same-format inputs are skipped.
- Confirm pre-existing destination files are skipped without overwrite.
- Confirm output files land beside their source files.

## Current known gaps
- The GPL-policy blocker is resolved for the current vendored binary, but the release bundle still needs the explicit P1 notice/source-offer material for FFmpeg and the linked external audio libraries before distribution.
- The P2 automation path is now scripted, but a real notarization pass still requires release-machine access to the Apple signing identity and stored `notarytool` credentials.
