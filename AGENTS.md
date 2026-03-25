# AudioConverter Agent Guide

## Scope
These instructions apply to the entire repository unless a deeper `AGENTS.md` overrides them.

## Project Summary
- `AudioConverter` is a macOS SwiftUI batch audio converter that shells out to a vendored FFmpeg binary.
- `project.yml` is the source of truth for project structure; `AudioConverter.xcodeproj` is generated from it.
- The current codebase targets macOS 14.0 and Swift 5.10.

## Repository Map
- `AudioConverter/App`: app entry point and shared app state
- `AudioConverter/Config`: checked-in build settings, including `BuildSettings.xcconfig`
- `AudioConverter/Core`: conversion, validation, startup checks, and FFmpeg integration
- `AudioConverter/Models`: domain models and state
- `AudioConverter/UI`: SwiftUI views and components
- `AudioConverter/UIAdapters`: platform-facing adapter seams
- `AudioConverter/Resources/ffmpeg`: vendored FFmpeg binary
- `AudioConverterTests`: unit and integration-style tests
- `AudioConverterUITests`: UI automation coverage
- `scripts`: build/package helpers
- `docs`: provenance, signing, and notice-bundle documentation

## Working Agreements
- Keep diffs small, targeted, and reversible.
- Prefer existing project patterns and utilities over new abstractions.
- Do not add new dependencies unless explicitly requested.
- Prefer deleting dead code over layering on workarounds.
- Add or update tests when behavior changes or bug fixes need regression coverage.
- If behavior is unclear, verify it in code or tests before claiming completion.

## Xcode / Build Rules
- When project structure, targets, build settings, or resource wiring changes, update `project.yml` first and make the matching checked-in change under `AudioConverter/Config` when applicable.
- Any committed `project.yml` change must be accompanied by the regenerated `AudioConverter.xcodeproj` diff.
- Manual edits to `AudioConverter.xcodeproj` are allowed only for documented XcodeGen gaps; otherwise, treat the project as generated output that must stay in sync with `project.yml`.
- Use the Xcode toolchain path from the README when invoking local build tooling:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate` (`xcodegen` must be available on `PATH`)
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme AudioConverter -destination 'platform=macOS' build`
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme AudioConverter -destination 'platform=macOS' test`

## FFmpeg / Release Rules
- Keep the vendored binary path stable unless the task explicitly changes packaging: `AudioConverter/Resources/ffmpeg/ffmpeg`.
- If FFmpeg provenance, licensing, or bundled assets change, update the matching documentation and scripts in `docs/` and `scripts/` together.
- Treat `docs/notice-bundle/` as the source of truth for third-party notice bundle assets.

## Verification Expectations
- Start with the most targeted verification for the files you changed, then broaden as needed.
- For app logic changes, prefer relevant `AudioConverterTests` coverage.
- For UI flow changes, use `AudioConverterUITests` when practical.
- Report any verification you could not run and why.

## Repo Hygiene
- Do not commit generated build output or local state.
- Preserve `.gitignore` coverage for Xcode artifacts, `build/`, `DerivedData/`, `.build/`, and `.omx/`.
- Keep documentation in sync when changing developer workflow or release steps.
