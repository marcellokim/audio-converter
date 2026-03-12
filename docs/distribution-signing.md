# Distribution and signing notes

## v1 assumptions
- Platform: macOS only
- Distribution: direct download outside the Mac App Store
- Sandbox: disabled for v1
- Signing goal: signed and notarized release builds

## Planned release flow
1. Generate the Xcode project from `project.yml`.
2. Bundle `AudioConverter.app/Contents/Resources/ffmpeg/ffmpeg` during the build.
3. Sign the nested ffmpeg executable before signing the app bundle for release.
4. Submit the signed app for notarization.
5. Staple the notarization ticket before distribution.

## Current scaffold status
- `scripts/embed-ffmpeg.sh` copies the vendored ffmpeg binary into the app bundle and applies `chmod +x`.
- Release-specific signing automation still needs implementation in a later cycle.

## Verified local commands
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /opt/homebrew/bin/xcodegen generate`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme AudioConverter -destination 'platform=macOS' build`


## Related release documents
- `docs/release-checklist.md` — ship checklist for pre-release validation, signing, notarization, and manual QA.
- `docs/ffmpeg-licensing.md` — licensing gate for the vendored FFmpeg artifact.
