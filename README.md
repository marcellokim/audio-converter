# AudioConverter

AudioConverter is a macOS SwiftUI desktop app for batch audio conversion and ordered multi-file merging, powered by a vendored FFmpeg binary.

It is designed as a portfolio-quality product/code sample: a native Mac interface, clear state management, deterministic UI automation seams, and a tested FFmpeg execution pipeline.

## Highlights

- **Native macOS app** built with **SwiftUI** and targeting **macOS 14.0 / Swift 5.10**
- **Batch conversion workflow** for common audio formats including MP3, M4A, AAC, WAV, FLAC, AIFF, OPUS, and OGG
- **Ordered merge workflow** that lets users stage multiple files, rearrange playback order, choose a destination, and export a single merged file
- **Adaptive workspace UI** with a single root scroll surface, stable accessibility identifiers, and layout behavior tuned for both wide and compact window sizes
- **Startup self-check + retry flow** for the bundled FFmpeg dependency
- **Deterministic UI-test hooks** for file selection, save-panel flows, startup failures, and merge scenarios
- **Real FFmpeg integration coverage** alongside unit and UI automation tests

## Product overview

AudioConverter currently supports two primary workflows:

1. **Batch Convert**
   Select one or more source files and export converted outputs beside the originals.

2. **Merge into One**
   Stage multiple files, adjust their playback order, choose a destination path, and create one merged output file.

The latest UI refresh keeps both workflows inside one adaptive workspace instead of splitting behavior across multiple screens. This preserves a compact desktop experience while keeping staging, export controls, validation, and live progress distinct.

## Engineering focus

This project emphasizes:

- **Brownfield-safe UI work**: stable selector contracts and non-duplicated interactive controls across adaptive layouts
- **Clear app-state boundaries**: UI, session orchestration, FFmpeg command building, and platform adapters are separated into focused layers
- **Testability**: deterministic hooks for UI automation and reusable seams around file selection, destination selection, startup checks, and conversion sessions
- **Operational correctness**: serial batch execution, cancellation handling, cleanup of temporary outputs, and explicit snapshot-based progress reporting

## Current implementation status

As of **March 29, 2026**, the repository includes:

- a generated Xcode project backed by **`project.yml`**
- the SwiftUI app in **`AudioConverter/`**
- unit tests, UI automation tests, and real-FFmpeg integration coverage in **`AudioConverterTests/`** and **`AudioConverterUITests/`**
- a vendored macOS **arm64** FFmpeg binary at **`AudioConverter/Resources/ffmpeg/ffmpeg`**
- scripts and documentation for FFmpeg provenance, release packaging, distribution signing/notarization, and notice-bundle packaging

The current implementation is verified with:

- startup self-check coverage for the bundled FFmpeg dependency
- batch conversion tests from staging through completion/cancellation
- merge-mode tests covering ordering, destination gating, and a single merged status row
- adaptive UI selector checks that keep automation stable after layout changes

## Architecture at a glance

- **`AudioConverter/App`** — app entry point and shared app state
- **`AudioConverter/Core`** — FFmpeg command building, conversion/merge execution, validation, and startup checks
- **`AudioConverter/Models`** — domain models and batch snapshot state
- **`AudioConverter/UI`** — SwiftUI views and reusable components
- **`AudioConverter/UIAdapters`** — platform-facing seams such as open/save panel handling
- **`AudioConverterTests`** — unit and integration-style coverage
- **`AudioConverterUITests`** — XCUI automation coverage
- **`docs/`** — FFmpeg provenance, notice bundle, release/signing notes, and UI workspace contract

## Repository structure

- `project.yml` — XcodeGen source of truth
- `AudioConverter.xcodeproj` — generated Xcode project
- `AudioConverter/Resources/ffmpeg/ffmpeg` — vendored FFmpeg executable
- `scripts/embed-ffmpeg.sh` — embeds the vendored FFmpeg binary into the app bundle
- `scripts/package-notice-bundle.sh` — stages the canonical `ThirdPartyNotices/` release packet
- `scripts/release-sign-and-notarize.sh` — stages notices, signs the helper/app bundle, and drives notarization for the zipped release artifact
- `docs/ffmpeg-provenance.md` — FFmpeg source/build provenance
- `docs/distribution-signing.md` — signing and notarization notes
- `docs/uiux-workspace.md` — adaptive workspace contract and selector constraints
- `docs/notice-bundle/` — source-of-truth notice bundle assets

## Supported output formats

- `mp3`
- `m4a`
- `aac`
- `wav`
- `flac`
- `aiff`
- `opus`
- `ogg`

## Build and test

Generate the Xcode project:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /opt/homebrew/bin/xcodegen generate
```

Build the app:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme AudioConverter -destination 'platform=macOS' build
```

Run the full test suite:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme AudioConverter -destination 'platform=macOS' test
```

## Run locally

### Option 1 — Run from Xcode
1. Generate the project if needed:
   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /opt/homebrew/bin/xcodegen generate
   ```
2. Open `AudioConverter.xcodeproj` in Xcode.
3. Select the **AudioConverter** scheme.
4. Choose **My Mac** as the run destination.
5. Press **Run**.

### Option 2 — Run from Terminal
Build a local Debug app bundle into the repo `build/` directory:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project AudioConverter.xcodeproj \
  -scheme AudioConverter \
  -configuration Debug \
  SYMROOT=build \
  build
```

Launch the built app:

```bash
open build/Debug/AudioConverter.app
```

### Optional release-lane rehearsal
If you want to rehearse the direct-download release packaging flow locally without Apple signing credentials:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project AudioConverter.xcodeproj \
  -scheme AudioConverter \
  -configuration Release \
  SYMROOT=build \
  build

scripts/release-sign-and-notarize.sh \
  --mode rehearse \
  --app build/Release/AudioConverter.app
```

## Latest local verification

Verified on **March 29, 2026** with:

- `xcodebuild -scheme AudioConverter -destination 'platform=macOS' build`
- `xcodebuild -project AudioConverter.xcodeproj -scheme AudioConverter -configuration Release SYMROOT=build build`
- `xcodebuild -scheme AudioConverter -destination 'platform=macOS' -only-testing:AudioConverterTests test`
- `xcodebuild -project AudioConverter.xcodeproj -scheme AudioConverter -destination 'platform=macOS' -only-testing:AudioConverterTests/RealFFmpegIntegrationTests test`
- `bash -n scripts/release-sign-and-notarize.sh`
- `scripts/release-sign-and-notarize.sh --mode rehearse --app build/Release/AudioConverter.app`
- `scripts/release-sign-and-notarize.sh --mode run --app <temp-copy>.app --signing-identity - --nested-signing-identity - --skip-notarization`

All of the above completed successfully in the local workspace.

## FFmpeg and licensing notes

The vendored FFmpeg artifact is currently an **LGPL-compatible local build of FFmpeg 8.0.1 for macOS arm64**. The recorded provenance, build context, and notice-bundle inputs live in:

- `docs/ffmpeg-provenance.md`
- `docs/notice-bundle/`

## Current caveats / next steps

- The repository now includes a repeatable zipped-release packaging/signing/notarization lane, but a real Developer ID signing + Apple notarization submission still requires release-machine access to the Apple credentials.
- The repository is already suitable as a portfolio/code-review sample, and the remaining release step is operational rather than code-completeness work.
- External desktop overlays can still slow UI automation in rare cases even when tests pass; the app-side selector/test seams remain stable.
