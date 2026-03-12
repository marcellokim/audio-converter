# FFmpeg licensing notes

## v1 policy
- The shipped FFmpeg artifact must be an **LGPL-compatible** build for direct distribution.
- The repo's prior Martin Riedl binary is **not** acceptable for that policy because upstream `versions.txt` reported `--enable-gpl`; the current vendored artifact replaces it with an official-source local build whose `ffmpeg -L` output reports LGPL `2.1 or later`.

## Required release package contents
1. Exact FFmpeg version and architecture (`arm64` for v1).
2. Source provenance for the shipped binary, including download URL or internal artifact source.
3. SHA256 for the shipped binary.
4. Configure flags used to produce the shipped binary.
5. Enumerated enabled audio encoders and muxers required by the app.
6. Copy of the applicable FFmpeg / LGPL license notices distributed with the app, plus any third-party notices required by linked external libraries.
7. Offer or instructions for obtaining the corresponding source for the shipped FFmpeg build. If the team builds from official FFmpeg sources internally, record the exact `ffmpeg.org` release tarball or git commit and any local patches.
8. If the shipped build links external audio libraries such as `libmp3lame`, `libopus`, or `libvorbis`, record their versions and retain their matching license/provenance notes beside the FFmpeg record.

## Review notes for the current repo state
- `scripts/embed-ffmpeg.sh` embeds a vendored binary when present and now emits a deterministic build stamp so the Xcode script phase can declare outputs cleanly.
- `AudioConverter/Resources/ffmpeg/ffmpeg` is now populated with a concrete macOS `arm64` artifact and current integration tests exercise it successfully.
- The current artifact is built from the official FFmpeg `8.0.1` source tarball, and the exact source URL/checksums + shipped binary checksum are recorded in `docs/ffmpeg-provenance.md`.
- The shipped binary's build configuration omits `--enable-gpl` and `--enable-nonfree`; `ffmpeg -L` reports LGPL `2.1 or later`.
- The final release review must confirm the shipped binary still contains the encoder and muxer set documented in `docs/ffmpeg-provenance.md`.

## Release decision gate
Do not ship until all of the following are true:
- The vendored binary is present in the repo or release pipeline input.
- The vendored binary's actual license mode matches the product's distribution policy.
- Provenance, checksums, and license notices are updated to match the shipped artifact.
- The recorded metadata taken from the shipped binary (`-version`, `-buildconf`, encoder list, muxer list) matches the published provenance/licensing notes.
- The signed release bundle contains `Contents/Resources/ffmpeg/ffmpeg`.

## Current blocker
- The old **missing binary** blocker is resolved.
- The old **GPL-compatibility** blocker is resolved for the currently vendored binary: the recorded build configuration omits GPL-enabling flags and `ffmpeg -L` reports LGPL `2.1 or later`.
- The remaining **licensing/compliance** work is release packaging: include FFmpeg license text/source instructions plus the notices/provenance for linked external audio libraries (`libmp3lame`, `libopus`, `libvorbis`, `libogg`) before distribution.
