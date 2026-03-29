# FFmpeg licensing notes

## v1 policy
- The shipped FFmpeg artifact must be an **LGPL-compatible** build for direct distribution.
- The repo's prior Martin Riedl binary is **not** acceptable for that policy because upstream `versions.txt` reported `--enable-gpl`; the current vendored artifact replaces it with an official-source local build whose `ffmpeg -L` output reports LGPL `2.1 or later`.

## Canonical distribution notice bundle (P1 complete)
Stage the release-time notice packet under:

```text
AudioConverter.app/Contents/Resources/ThirdPartyNotices/
```

Generate it with:

```bash
scripts/package-notice-bundle.sh <destination>
```

The canonical bundle contains:
1. `README.md` — reviewer-facing overview plus expected bundle placement.
2. `SOURCE-OFFER.md` — instructions for obtaining the exact corresponding source tarballs.
3. `THIRD-PARTY-NOTICES.md` — a reviewer map from each bundled component to its license notice and provenance record.
4. `FFmpeg/ffmpeg-licensing.md` — this policy/gate document.
5. `FFmpeg/ffmpeg-provenance.md` — version, SHA256, build configuration, and linked-library provenance.
6. `FFmpeg/COPYING.LGPLv2.1.txt` — upstream FFmpeg LGPL notice text.
7. `ExternalLibraries/libmp3lame-COPYING.txt` and `ExternalLibraries/libmp3lame-LICENSE.txt` — upstream libmp3lame LGPL/license-use notes.
8. `ExternalLibraries/libopus-COPYING.txt`, `ExternalLibraries/libvorbis-COPYING.txt`, and `ExternalLibraries/libogg-COPYING.txt` — upstream redistribution notices for the linked codec libraries.

## Required release package contents
1. Exact FFmpeg version and architecture (`arm64` for v1).
2. Source provenance for the shipped binary, including download URL or internal artifact source.
3. SHA256 for the shipped binary.
4. Configure flags used to produce the shipped binary.
5. Enumerated enabled audio encoders and muxers required by the app.
6. The canonical `ThirdPartyNotices/` bundle above, including FFmpeg/LGPL text plus the linked external-library notices.
7. Instructions for obtaining the corresponding source for the shipped FFmpeg build. If the team builds from official FFmpeg sources internally, record the exact `ffmpeg.org` release tarball or git commit and any local patches.
8. If the shipped build links external audio libraries such as `libmp3lame`, `libopus`, or `libvorbis`, record their versions and retain their matching license/provenance notes beside the FFmpeg record.

## Review notes for the current repo state
- `scripts/package-notice-bundle.sh` now stages the canonical `ThirdPartyNotices/` bundle from repo-tracked notice assets.
- `docs/notice-bundle/licenses/` now carries the exact upstream notice texts for FFmpeg, `libmp3lame`, `libopus`, `libvorbis`, and `libogg`.
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
- The release artifact contains the canonical `ThirdPartyNotices/` bundle exactly once, with the files listed above.
- The signed release bundle contains `Contents/Helpers/ffmpeg`.

## Current blocker
- The old **missing binary** blocker is resolved.
- The old **GPL-compatibility** blocker is resolved for the currently vendored binary: the recorded build configuration omits GPL-enabling flags and `ffmpeg -L` reports LGPL `2.1 or later`.
- The old **missing notice bundle** blocker is resolved in-repo: the canonical `ThirdPartyNotices/` payload now lives under `docs/notice-bundle/` and can be staged with `scripts/package-notice-bundle.sh`.
- The remaining operational blocker is access to the Apple signing identity and stored `notarytool` credentials on the release machine.
