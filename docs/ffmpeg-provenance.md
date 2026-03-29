# FFmpeg provenance

## Current vendored artifact
The repository now vendors a concrete FFmpeg artifact at `AudioConverter/Resources/ffmpeg/ffmpeg`.

| Field | Value |
| --- | --- |
| Version | `8.0.1` |
| Platform / architecture | macOS `arm64` |
| Vendored binary path | `AudioConverter/Resources/ffmpeg/ffmpeg` |
| Vendored binary SHA256 | `931075f4640675a16f8556f2833cada7b427b9d57b742bb0d2a582488a1f48a8` |
| Vendored binary size | `22,540,424` bytes |
| Source / provenance | Official FFmpeg release tarball, built locally in `.omx/tmp/ffmpeg-lgpl-build` |
| Source tarball URL | `https://ffmpeg.org/releases/ffmpeg-8.0.1.tar.xz` |
| Source tarball SHA256 | `05ee0b03119b45c0bdb4df654b96802e909e0a752f72e4fe3794f487229e5a41` |
| Build toolchain | Apple clang `17.0.0 (clang-1700.6.4.2)` |
| Linked audio libraries enabled at build time | `libmp3lame` (`lame 3.100`), `libopus` (`opus 1.6.1`), `libvorbis` (`libvorbis 1.3.7` + `libogg 1.3.6`) |
| License mode | `ffmpeg -L` reports GNU Lesser General Public License `2.1 or later` |
| Dynamic dependency summary (`otool -L`) | `libSystem.B.dylib`, `CoreFoundation`, `CoreVideo`, `CoreMedia` |

## Configure flags recorded from the shipped binary (`ffmpeg -buildconf`)
```text
--prefix=/Users/ydmac/Documents/audio-converter/.omx/tmp/ffmpeg-lgpl-build/out --cc=clang --arch=arm64 --target-os=darwin --disable-debug --disable-doc --disable-shared --enable-static --disable-autodetect --pkg-config=/Users/ydmac/Documents/audio-converter/.omx/tmp/ffmpeg-lgpl-build/pkg-config-shim --enable-libmp3lame --enable-libopus --enable-libvorbis --extra-cflags=-I/opt/homebrew/opt/lame/include --extra-ldflags='-L/Users/ydmac/Documents/audio-converter/.omx/tmp/ffmpeg-lgpl-build/static-libs -Wl,-search_paths_first'
```

The absolute paths above are the original build-host paths emitted by the binary itself.

## External library provenance captured for the current build
The current vendored FFmpeg binary has only system runtime dependencies according to `otool -L`, but the build still relies on external codec libraries for MP3 / Opus / Vorbis support. Their corresponding source provenance is part of the distribution notice bundle as well as this record:

| Library | Version | Source URL | Source SHA256 | Bundled notice file(s) |
| --- | --- | --- | --- | --- |
| `lame` | `3.100` | `https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz` | `ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e` | `ExternalLibraries/libmp3lame-COPYING.txt`, `ExternalLibraries/libmp3lame-LICENSE.txt` |
| `opus` | `1.6.1` | `https://ftp.osuosl.org/pub/xiph/releases/opus/opus-1.6.1.tar.gz` | `6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1` | `ExternalLibraries/libopus-COPYING.txt` |
| `libvorbis` | `1.3.7` | `https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.7.tar.xz` | `b33cc4934322bcbf6efcbacf49e3ca01aadbea4114ec9589d1b1e9d20f72954b` | `ExternalLibraries/libvorbis-COPYING.txt` |
| `libogg` | `1.3.6` | `https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.6.tar.gz` | `83e6704730683d004d20e21b8f7f55dcb3383cdf84c0daedf30bde175f774638` | `ExternalLibraries/libogg-COPYING.txt` |

## Distribution notice bundle linkage
- Source assets for the canonical notice packet live in `docs/notice-bundle/`.
- Stage the final reviewer-facing bundle with `scripts/package-notice-bundle.sh <destination>`.
- The packaged root must be `ThirdPartyNotices/`, with the FFmpeg provenance/licensing docs copied verbatim into `ThirdPartyNotices/FFmpeg/`.
- `docs/notice-bundle/THIRD-PARTY-NOTICES.md` and `docs/notice-bundle/SOURCE-OFFER.md` provide the reviewer summary and corresponding-source instructions that accompany this provenance record.
- Release builds embed the vendored executable inside the signed app bundle at `Contents/Helpers/ffmpeg` while keeping the repo-tracked source artifact at `AudioConverter/Resources/ffmpeg/ffmpeg`.

## Required audio capabilities validated against the vendored binary
- Encoders: `libmp3lame`, `aac`, `pcm_s16le`, `flac`, `pcm_s16be`, `libopus`, `libvorbis`
- Muxers: `mp3`, `ipod`, `adts`, `wav`, `flac`, `aiff`, `opus`, `ogg`

The repo's startup self-check, real-FFmpeg integration test, and fresh scheme test run validate the shipped binary against these capabilities.

## Operational status vs. release status
- **Resolved:** the repo no longer ships the prior GPL-enabled third-party artifact. The vendored binary now comes from an official FFmpeg source tarball, its build configuration does **not** include `--enable-gpl` / `--enable-nonfree`, and `ffmpeg -L` reports LGPL `2.1 or later`.
- **Resolved for P1:** the matching FFmpeg + external-library notice/source-offer payload now lives in `docs/notice-bundle/` and can be staged as `ThirdPartyNotices/` with `scripts/package-notice-bundle.sh`.
- **Remaining release-machine requirement:** run the scripted release packaging/signing/notarization lane with Apple Developer signing + notarization credentials.

## Related release documents
- `docs/ffmpeg-licensing.md` — release-time license and source-distribution obligations for the shipped FFmpeg binary.
- `docs/notice-bundle/README.md` — source-of-truth bundle layout and staging instructions.
