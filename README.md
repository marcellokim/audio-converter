# AudioConverter

FFmpeg-based macOS batch audio converter scaffold.

## Current status
This repository now contains the first implementation cycle:
- XcodeGen project spec in `project.yml`
- macOS SwiftUI app scaffold in `AudioConverter/`
- initial unit/UI test targets
- FFmpeg embed build script in `scripts/embed-ffmpeg.sh`
- format registry and startup self-check core files
- distribution and FFmpeg provenance notes in `docs/`

The app is still an early scaffold. File picking, conversion coordination, and release signing automation are not finished yet.

## Project structure
- `project.yml`: XcodeGen project definition
- `AudioConverter/App`: app entry point and shared app state
- `AudioConverter/Core`: format registry, validation, FFmpeg command building, startup checks
- `AudioConverter/Models`: core state and format models
- `AudioConverter/UI`: current SwiftUI shell
- `AudioConverterTests`: unit tests
- `AudioConverterUITests`: UI smoke test
- `scripts/embed-ffmpeg.sh`: copies vendored FFmpeg into the app bundle
- `docs/distribution-signing.md`: signing and notarization notes
- `docs/ffmpeg-provenance.md`: current FFmpeg development reference

## Supported output formats in the current registry
- `mp3`
- `m4a`
- `aac`
- `wav`
- `flac`
- `aiff`
- `opus`
- `ogg`

## Build
Generate the Xcode project:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /opt/homebrew/bin/xcodegen generate
```

Build the app:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme AudioConverter -destination 'platform=macOS' build
```

Run tests:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme AudioConverter -destination 'platform=macOS' test
```

Current verification note: unit tests pass, but the current UI test target fails to load with a macOS code-signing Team ID mismatch in `AudioConverterUITests-Runner`.

## FFmpeg bundle expectation
The build script expects a vendored binary at:

```text
AudioConverter/Resources/ffmpeg/ffmpeg
```

If the binary is missing, the build currently emits a warning and skips embedding.

## Next implementation milestones
- add `NSOpenPanel` adapter/presenter for file selection
- connect startup self-check to app state
- implement output path resolution and conversion engine
- replace the development FFmpeg reference with a redistributable LGPL-compatible vendored artifact
