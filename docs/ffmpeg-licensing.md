# FFmpeg licensing notes

## v1 policy
- The shipped FFmpeg artifact must be an **LGPL-compatible** build for direct distribution.
- The current Homebrew development binary documented in `docs/ffmpeg-provenance.md` is **not** acceptable for release because it reports `--enable-gpl`.

## Required release package contents
1. Exact FFmpeg version and architecture (`arm64` for v1).
2. Source provenance for the shipped binary, including download URL or internal artifact source.
3. SHA256 for the shipped binary.
4. Configure flags used to produce the shipped binary.
5. Enumerated enabled audio encoders and muxers required by the app.
6. Copy of the applicable FFmpeg / LGPL license notices distributed with the app.
7. Offer or instructions for obtaining the corresponding source for the shipped FFmpeg build.

## Review notes for the current repo state
- `scripts/embed-ffmpeg.sh` embeds a vendored binary when present and now emits a deterministic build stamp so the Xcode script phase can declare outputs cleanly.
- `AudioConverter/Resources/ffmpeg/` does not yet contain the release artifact, so current builds only validate the app scaffold and script wiring.
- The final release review must confirm the shipped binary still contains the encoder and muxer set documented in `docs/ffmpeg-provenance.md`.

## Release decision gate
Do not ship until all of the following are true:
- The vendored binary is present in the repo or release pipeline input.
- The vendored binary is LGPL-compatible.
- Provenance, checksums, and license notices are updated to match the shipped artifact.
- The signed release bundle contains `Contents/Resources/ffmpeg/ffmpeg`.
