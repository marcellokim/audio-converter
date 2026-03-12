# FFmpeg provenance

## Current local development reference
This scaffold records the local FFmpeg binary already validated during planning. It is a development reference only, not yet a finalized redistributable artifact.

| Field | Value |
| --- | --- |
| Version | 8.0 |
| Source / provenance | Homebrew formula `ffmpeg` installed under `/opt/homebrew/Cellar/ffmpeg/8.0_1` |
| Binary path used for validation | `/opt/homebrew/bin/ffmpeg` |
| SHA256 | `fe026c818fa2f3b07263bc92c559b21518014c727720db2dfb3a24d372618116` |
| License mode | Homebrew build reports `--enable-gpl`; not yet suitable for the planned LGPL-compatible vendored release artifact |
| Target architecture | arm64 (planned v1 target) |

## Configure flags captured during planning
```text
--prefix=/opt/homebrew/Cellar/ffmpeg/8.0_1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gnutls --enable-gpl --enable-libaom --enable-libaribb24 --enable-libbluray --enable-libdav1d --enable-libharfbuzz --enable-libjxl --enable-libmp3lame --enable-libopus --enable-librav1e --enable-librist --enable-librubberband --enable-libsnappy --enable-libsrt --enable-libssh --enable-libsvtav1 --enable-libtesseract --enable-libtheora --enable-libvidstab --enable-libvmaf --enable-libvorbis --enable-libvpx --enable-libwebp --enable-libx264 --enable-libx265 --enable-libxml2 --enable-libxvid --enable-lzma --enable-libfontconfig --enable-libfreetype --enable-frei0r --enable-libass --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libopenjpeg --enable-libspeex --enable-libsoxr --enable-libzmq --enable-libzimg --disable-libjack --disable-indev=jack --enable-videotoolbox --enable-audiotoolbox --enable-neon
```

## Required audio capabilities validated for v1 planning
- Encoders: `libmp3lame`, `aac`, `pcm_s16le`, `flac`, `pcm_s16be`, `libopus`, `libvorbis`
- Muxers: `mp3`, `ipod`, `adts`, `wav`, `flac`, `aiff`, `opus`, `ogg`

## Follow-up required before release
- Replace the development reference with a vendored LGPL-compatible FFmpeg artifact.
- Record the final artifact source URL, exact source tarball, rebuild recipe, and redistributable license notices.


## Related release documents
- `docs/ffmpeg-licensing.md` — release-time license and source-distribution obligations for the shipped FFmpeg binary.
- `docs/release-checklist.md` — release gate that ensures provenance and licensing stay aligned with the shipped artifact.
