# AudioConverter

AudioConverter is a native macOS SwiftUI app for batch audio conversion and ordered multi-file merging, powered by a vendored FFmpeg binary.

It is designed as a portfolio-quality product/code sample: a native Mac interface, clear queue state, deterministic UI automation seams, and a tested FFmpeg execution pipeline that can run multiple safe conversion jobs concurrently.

## Highlights

- **Native macOS app** built with **SwiftUI** and targeting **macOS 14.0 / Swift 5.10**
- **Batch conversion workflow** for common audio formats including MP3, M4A, AAC, WAV, FLAC, AIFF, OPUS, and OGG
- **Ordered merge workflow** that lets users stage multiple files, rearrange playback order, choose a destination, and export a single merged file
- **Adaptive workspace UI** with a single root scroll surface, compact queue controls, stable accessibility identifiers, and layout behavior tuned for both wide and compact window sizes
- **Bounded queue scheduler** with automatic CPU-aware concurrency, manual slot control, and same-output reservation to avoid conflicting active jobs
- **Startup self-check + retry flow** for the bundled FFmpeg dependency
- **Deterministic UI-test hooks** for file selection, save-panel flows, startup failures, and merge scenarios
- **Real FFmpeg integration coverage** alongside unit and UI automation tests

## Product overview

AudioConverter currently supports two primary workflows:

1. **Batch Convert**
   Select one or more source files and export converted outputs beside the originals.

2. **Merge into One**
   Stage multiple files, adjust their playback order, choose a destination path, and create one merged output file.

The latest UI refresh keeps both workflows inside one adaptive workspace instead of splitting behavior across multiple screens. This preserves a compact desktop experience while keeping staging, export controls, validation, queue scheduling, and live progress distinct.

## Engineering focus

This project emphasizes:

- **Brownfield-safe UI work**: stable selector contracts and non-duplicated interactive controls across adaptive layouts
- **Clear app-state boundaries**: UI, session orchestration, FFmpeg command building, and platform adapters are separated into focused layers
- **Testability**: deterministic hooks for UI automation and reusable seams around file selection, destination selection, startup checks, and conversion sessions
- **Operational correctness**: bounded queue scheduling, cancellation handling, output-conflict avoidance, cleanup of temporary outputs, and explicit snapshot-based progress reporting

## Current implementation status

As of **April 26, 2026**, the repository includes:

- a generated Xcode project backed by **`project.yml`**
- the SwiftUI app in **`AudioConverter/`**
- unit tests, UI automation tests, and real-FFmpeg integration coverage in **`AudioConverterTests/`** and **`AudioConverterUITests/`**
- a vendored macOS **arm64** FFmpeg binary at **`AudioConverter/Resources/ffmpeg/ffmpeg`**
- scripts and documentation for FFmpeg provenance, release packaging, distribution signing/notarization, and notice-bundle packaging
- bounded queue scheduling with automatic CPU-aware concurrency and a manual slot override for batch conversion
- deterministic single-slot merge execution so ordered exports and destination replacement stay predictable

The current implementation is verified with:

- startup self-check coverage for the bundled FFmpeg dependency
- batch conversion tests from staging through completion/cancellation
- merge-mode tests covering ordering, destination gating, and a single merged status row
- scheduler tests covering concurrency limits and same-output reservation
- adaptive UI selector checks that keep automation stable after layout changes

## Quick start

```bash
git clone <repo-url>
cd audio-converter
scripts/run-local.sh
```

`scripts/run-local.sh` generates the Xcode project with XcodeGen, builds a Debug app bundle into `build/Debug/`, and opens the app.

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
- `AudioConverter/Config/Release.entitlements` — explicit release entitlements policy used by the signing/notarization lane
- `AudioConverter/Resources/ffmpeg/ffmpeg` — vendored FFmpeg executable
- `scripts/embed-ffmpeg.sh` — embeds the vendored FFmpeg binary into the app bundle
- `scripts/package-notice-bundle.sh` — stages the canonical `ThirdPartyNotices/` release packet
- `scripts/release-sign-and-notarize.sh` — stages notices, signs the helper/app bundle, and drives notarization for the zipped release artifact
- `scripts/run-local.sh` — generates the project, builds Debug, and launches the app locally
- `scripts/rehearse-release.sh` — builds Release and runs the local release-lane rehearsal
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

## Prerequisites

- macOS 14.0 or newer
- Xcode installed at `/Applications/Xcode.app`
- XcodeGen available on `PATH` or at `/opt/homebrew/bin/xcodegen`
- No separate FFmpeg install is required for normal app use; the repository vendors the macOS arm64 binary used by the app

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

Run the main non-UI unit coverage:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme AudioConverter -destination 'platform=macOS' \
  -only-testing:AudioConverterTests test
```

## Run locally

### Fastest path
```bash
scripts/run-local.sh
```

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
scripts/rehearse-release.sh
```

## Environment variables

No runtime environment variables are required to build or run the app locally.

The release signing/notarization script can read these optional variables, also listed in `.env.example`:

- `AUDIOCONVERTER_SIGNING_IDENTITY`
- `AUDIOCONVERTER_NESTED_SIGNING_IDENTITY`
- `AUDIOCONVERTER_APP_ENTITLEMENTS`
- `AUDIOCONVERTER_NOTARY_PROFILE`
- `AUDIOCONVERTER_TEAM_ID`

These values are release-machine configuration, not application secrets. Do not commit real signing identities, keychain profiles, or local `.env` files.

## Deployment and distribution

AudioConverter is a desktop app, so the realistic portfolio distribution path is a signed and notarized macOS app archive for direct download. The repo includes the local packaging/signing rehearsal lane, but real Developer ID signing and Apple notarization require credentials on the release machine.

Recommended review path:

1. Run `scripts/run-local.sh` for local review.
2. Run `scripts/rehearse-release.sh` to validate the release bundle layout without Apple credentials.
3. Follow `docs/distribution-signing.md` on a release machine for Developer ID signing and notarization.

## Screenshots

No screenshots are committed yet. Run `scripts/run-local.sh` to inspect the current native macOS UI locally.

## Latest local verification

Verified on **April 26, 2026** with:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme AudioConverter -destination 'platform=macOS' build`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme AudioConverter -destination 'platform=macOS' -only-testing:AudioConverterTests/AudioConverterTests test`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme AudioConverter -destination 'platform=macOS' -only-testing:AudioConverterTests/ConversionCoordinatorTests test`
- `bash -n scripts/embed-ffmpeg.sh scripts/package-notice-bundle.sh scripts/rehearse-release.sh scripts/release-sign-and-notarize.sh scripts/run-local.sh`
- `git diff --check`

All of the above completed successfully in the local workspace. Full UI automation and Apple notarization were not run in this verification pass.

## FFmpeg and licensing notes

The vendored FFmpeg artifact is currently an **LGPL-compatible local build of FFmpeg 8.0.1 for macOS arm64**. The recorded provenance, build context, and notice-bundle inputs live in:

- `docs/ffmpeg-provenance.md`
- `docs/notice-bundle/`

## Current caveats / next steps

- The repository now includes a repeatable zipped-release packaging/signing/notarization lane, but a real Developer ID signing + Apple notarization submission still requires release-machine access to the Apple credentials.
- Screenshots are not committed yet, so reviewers need to run the app locally to inspect the current UI.
- External desktop overlays can still slow UI automation in rare cases even when tests pass; the app-side selector/test seams remain stable.
