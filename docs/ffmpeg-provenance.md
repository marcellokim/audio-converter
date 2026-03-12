# FFmpeg provenance

## Current vendored artifact
The repository now vendors a concrete FFmpeg artifact at `AudioConverter/Resources/ffmpeg/ffmpeg`.

| Field | Value |
| --- | --- |
| Version | `8.0.1` |
| Platform / architecture | macOS `arm64` |
| Vendored binary path | `AudioConverter/Resources/ffmpeg/ffmpeg` |
| Vendored binary SHA256 | `3b586ff896c0339e8fd574c143aaccac23c80789341e22d4202f8013a133d3a4` |
| Source / provenance | Martin Riedl FFmpeg build server |
| Detail page | `https://ffmpeg.martin-riedl.de/info/detail/macos/arm64/1766430132_8.0.1` |
| Download URL (zip) | `https://ffmpeg.martin-riedl.de/download/macos/arm64/1766430132_8.0.1/ffmpeg.zip` |
| Download ZIP SHA256 | `c56f4e2b2ce26a61becf890d8da3415347a1d7d4418cb514915f21612358b790` |
| Created timestamp | `22 Dec 2025 20:02 CET` |
| Build-script source | `https://git.martin-riedl.de/ffmpeg/build-script` |
| License mode | Upstream `versions.txt` reports `--enable-gpl`, so this artifact is GPL-enabled rather than LGPL-only |

## Configure flags recorded from upstream `versions.txt`
```text
--prefix=/Volumes/ffmpeg_arm64/out --pkg-config-flags=--static --extra-version='https://www.martin-riedl.de' --enable-gray --enable-libxml2 --enable-gpl --enable-libfreetype --enable-fontconfig --enable-libharfbuzz --enable-libsnappy --enable-libsrt --enable-libvmaf --enable-libass --enable-libklvanc --enable-libzimg --enable-libzvbi --enable-libaom --enable-libdav1d --enable-libopenh264 --enable-libopenjpeg --enable-librav1e --enable-libsvtav1 --enable-libvpx --enable-libvvenc --enable-libwebp --enable-libx264 --enable-libx265 --enable-libmp3lame --enable-libopus --enable-libvorbis --enable-libtheora
```

## Required audio capabilities validated against the vendored binary
- Encoders: `libmp3lame`, `aac`, `pcm_s16le`, `flac`, `pcm_s16be`, `libopus`, `libvorbis`
- Muxers: `mp3`, `ipod`, `adts`, `wav`, `flac`, `aiff`, `opus`, `ogg`

The repo's real-FFmpeg integration test and startup self-check both validate the current vendored binary against these capabilities.

## Operational status vs. release status
- **Resolved:** the repo no longer has a placeholder-only FFmpeg resource. The vendored binary is present and can be embedded into the app bundle.
- **Still blocked for an LGPL-only policy:** the chosen artifact is GPL-enabled because its upstream build configuration includes `--enable-gpl`.

## Related release documents
- `docs/ffmpeg-licensing.md` — release-time license and source-distribution obligations for the shipped FFmpeg binary.
- `docs/release-checklist.md` — release gate that ensures provenance and licensing stay aligned with the shipped artifact.
