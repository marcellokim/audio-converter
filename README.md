# AudioConverter

FFmpeg-based macOS batch audio converter for batch audio format conversion on macOS.

## Current status
This repository now contains:
- XcodeGen project spec in `project.yml`
- macOS SwiftUI app scaffold in `AudioConverter/`
- unit, UI, and real-FFmpeg integration test coverage in `AudioConverterTests/` and `AudioConverterUITests/`
- a vendored macOS `arm64` FFmpeg binary in `AudioConverter/Resources/ffmpeg/ffmpeg`
- FFmpeg embed build script in `scripts/embed-ffmpeg.sh`
- format registry, startup self-check, and conversion core files
- distribution, provenance, and licensing notes in `docs/`

The conversion core is now verified against the vendored FFmpeg binary, and it now includes a serial batch-session seam with stable per-file snapshot IDs, `queued -> running -> succeeded/skipped/failed/cancelled` state transitions, batch-wide cancel handling, and temp-file cleanup for cancelled work. The current SwiftUI shell continues to run a launch-time ffmpeg self-check, expose an in-app retry path for startup failures, open the real macOS file picker, drive conversions through reusable status/file-selection/format/batch components, and ship DEBUG-only deterministic UI-test hooks around the file-selection seam so UI automation does not depend on a human-operated `NSOpenPanel`.

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

Current verification note (2026-03-15): the vendored FFmpeg binary has been replaced with an LGPL-compatible local build from the official FFmpeg `8.0.1` source tarball, a fresh build succeeds, the real-FFmpeg integration test passes, and the full default scheme test run remains green.

## FFmpeg bundle expectation
The build script embeds the vendored binary from:

```text
AudioConverter/Resources/ffmpeg/ffmpeg
```

The current vendored artifact is FFmpeg `8.0.1` for macOS `arm64`, built locally from the official FFmpeg source tarball. See `docs/ffmpeg-provenance.md` for the exact source URL, checksums, and linked codec-library provenance.

## Current release caveat
- The vendored FFmpeg artifact is operationally present and verified for local conversion tests.
- The old GPL-policy blocker is resolved for the current vendored build: its recorded build configuration omits `--enable-gpl` / `--enable-nonfree`, and `ffmpeg -L` reports LGPL `2.1 or later`.
- Release packaging still needs the matching FFmpeg/LGPL notices and third-party codec-library provenance before distribution. See `docs/ffmpeg-licensing.md`.

## Next implementation milestones
- finish release automation for nested executable signing and notarization
- package the final FFmpeg/LGPL + external-library notice bundle for distribution
- expand deterministic UI automation from file-selection/startup flows into end-to-end conversion-completion coverage
