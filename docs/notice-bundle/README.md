# Distribution notice bundle

This directory is the source-of-truth payload for the AudioConverter v1 FFmpeg/LGPL notice bundle.

## Intended packaged location
Stage the generated bundle at:

```text
AudioConverter.app/Contents/Resources/ThirdPartyNotices/
```

Use `scripts/package-notice-bundle.sh <destination>` to materialize the final directory tree. The destination may be either an `.app` bundle or any staging directory.

## Packaged bundle layout

```text
ThirdPartyNotices/
├── README.md
├── SOURCE-OFFER.md
├── THIRD-PARTY-NOTICES.md
├── NOTICE-MANIFEST.txt
├── NOTICE-MANIFEST.sha256
├── FFmpeg/
│   ├── ffmpeg-licensing.md
│   ├── ffmpeg-provenance.md
│   └── COPYING.LGPLv2.1.txt
└── ExternalLibraries/
    ├── libmp3lame-COPYING.txt
    ├── libmp3lame-LICENSE.txt
    ├── libopus-COPYING.txt
    ├── libvorbis-COPYING.txt
    └── libogg-COPYING.txt
```

## Review expectations
- `docs/ffmpeg-licensing.md` defines the release-time compliance gate.
- `docs/ffmpeg-provenance.md` records the exact FFmpeg artifact, source tarballs, checksums, and codec-library versions.
- `THIRD-PARTY-NOTICES.md` gives a reviewer-facing map from each linked component to its bundled license file and provenance entry.
- `SOURCE-OFFER.md` gives the release packet's "how to obtain the corresponding source" instructions.
