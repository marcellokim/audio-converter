# Release checklist

## Scope for v1 direct distribution
- macOS-only release target (`arm64`)
- Direct download outside the Mac App Store
- App Sandbox disabled for v1
- Signed and notarized app bundle required before distribution

## Pre-release artifact checks
1. Confirm `AudioConverter/Resources/ffmpeg/ffmpeg` matches the approved vendored artifact recorded in `docs/ffmpeg-provenance.md`.
2. Verify the vendored binary matches the provenance record in `docs/ffmpeg-provenance.md`.
3. Confirm the licensing package described in `docs/ffmpeg-licensing.md` is included with the release artifact.
4. Regenerate the Xcode project from `project.yml` after any build-script change.
5. Build with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project AudioConverter.xcodeproj -scheme AudioConverter -destination 'platform=macOS' build`.
6. Run tests with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project AudioConverter.xcodeproj -scheme AudioConverter -destination 'platform=macOS' test`.

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
- The vendored FFmpeg binary is now present, but the current chosen artifact is GPL-enabled and therefore conflicts with the repo's earlier LGPL-only distribution policy.
- The release bundle still needs explicit notice packaging and a policy decision: either replace the vendored binary with an LGPL-compatible build or ship under GPL-compliant distribution terms.
- Release automation for nested executable signing and notarization remains documented but not fully scripted yet.
