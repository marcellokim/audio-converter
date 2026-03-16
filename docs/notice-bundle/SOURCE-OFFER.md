# Corresponding source offer

This release includes a locally built FFmpeg binary plus linked external audio codec libraries. The exact upstream source tarballs, versions, and SHA256 values for the shipped binary are recorded in `FFmpeg/ffmpeg-provenance.md`.

## How to obtain the corresponding source
1. Open `FFmpeg/ffmpeg-provenance.md`.
2. Download the exact source tarballs listed there for:
   - FFmpeg `8.0.1`
   - `lame` `3.100`
   - `opus` `1.6.1`
   - `libvorbis` `1.3.7`
   - `libogg` `1.3.6`
3. Verify each tarball against the recorded SHA256 value before rebuilding.
4. Rebuild FFmpeg with the recorded `ffmpeg -buildconf` flags and the linked codec-library inputs listed in the provenance document.

## Local patch status
- No local source patches are currently recorded for the shipped FFmpeg or linked codec-library inputs.
- If local patches are introduced later, add them to this notice bundle beside the upstream tarball references before shipping.
