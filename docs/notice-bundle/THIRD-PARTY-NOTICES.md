# Third-party notices

This bundle accompanies the AudioConverter v1 macOS release whenever the app ships with the vendored FFmpeg `8.0.1` binary described in `FFmpeg/ffmpeg-provenance.md`.

## Included components

| Component | Version | License notice(s) bundled here | Source / checksum reference |
| --- | --- | --- | --- |
| FFmpeg | `8.0.1` | `FFmpeg/COPYING.LGPLv2.1.txt` | `FFmpeg/ffmpeg-provenance.md` |
| `libmp3lame` | `3.100` | `ExternalLibraries/libmp3lame-COPYING.txt`, `ExternalLibraries/libmp3lame-LICENSE.txt` | `FFmpeg/ffmpeg-provenance.md` |
| `libopus` | `1.6.1` | `ExternalLibraries/libopus-COPYING.txt` | `FFmpeg/ffmpeg-provenance.md` |
| `libvorbis` | `1.3.7` | `ExternalLibraries/libvorbis-COPYING.txt` | `FFmpeg/ffmpeg-provenance.md` |
| `libogg` | `1.3.6` | `ExternalLibraries/libogg-COPYING.txt` | `FFmpeg/ffmpeg-provenance.md` |

## Notes for release review
- The bundled FFmpeg executable is distributed under LGPL `2.1 or later`; use `FFmpeg/COPYING.LGPLv2.1.txt` together with the provenance/build metadata in `FFmpeg/ffmpeg-provenance.md`.
- `libmp3lame` ships with an LGPL notice (`libmp3lame-COPYING.txt`) plus the upstream usage note in `libmp3lame-LICENSE.txt`.
- `libopus`, `libvorbis`, and `libogg` require their copyright notice and redistribution conditions to be reproduced with the binary distribution; those exact upstream `COPYING` files are bundled here.
- If the vendored FFmpeg artifact changes, update `docs/ffmpeg-provenance.md` first, refresh this bundle from the matching upstream sources, and restage it with `scripts/package-notice-bundle.sh`.
