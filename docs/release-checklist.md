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
6. Build with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project AudioConverter.xcodeproj -scheme AudioConverter -destination 'platform=macOS' build`.
7. Run the real-FFmpeg integration test with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project AudioConverter.xcodeproj -scheme AudioConverter -destination 'platform=macOS' -only-testing:AudioConverterTests/RealFFmpegIntegrationTests test`.
8. Run the full test suite with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project AudioConverter.xcodeproj -scheme AudioConverter -destination 'platform=macOS' test`.

## Signing + notarization
1. Archive a Release build with the final vendored ffmpeg binary embedded at `AudioConverter.app/Contents/Resources/ffmpeg/ffmpeg`.
2. Sign the nested ffmpeg executable before signing the app bundle.
3. Sign the app with hardened runtime enabled for the release configuration.
4. Submit the signed app for notarization.
5. Staple the notarization ticket to the final distributable.
6. Verify Gatekeeper acceptance on a clean macOS machine.

## Manual QA before shipping
- Launch the app and confirm startup self-check succeeds with the bundled ffmpeg binary.
- Convert representative inputs into each v1 output format.
- Confirm same-format inputs are skipped.
- Confirm pre-existing destination files are skipped without overwrite.
- Confirm output files land beside their source files.

## Current known gaps
- The GPL-policy blocker is resolved for the current vendored binary, but the release bundle still needs explicit notice packaging/source-offer material for FFmpeg and the linked external audio libraries.
- Release automation for nested executable signing and notarization remains documented but not fully scripted yet.
