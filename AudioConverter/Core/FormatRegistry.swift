import Foundation

enum FormatRegistry {
    private static let formatsByKey: [String: SupportedFormat] = {
        let formats: [SupportedFormat] = [
            SupportedFormat(
                id: "mp3",
                displayName: "MP3",
                outputExtension: "mp3",
                requiredEncoderKey: "libmp3lame",
                requiredMuxerKey: "mp3",
                ffmpegArgs: ["-vn", "-c:a", "libmp3lame", "-q:a", "2"]
            ),
            SupportedFormat(
                id: "m4a",
                displayName: "M4A",
                outputExtension: "m4a",
                requiredEncoderKey: "aac",
                requiredMuxerKey: "ipod",
                ffmpegArgs: ["-vn", "-c:a", "aac", "-b:a", "192k", "-f", "ipod"]
            ),
            SupportedFormat(
                id: "aac",
                displayName: "AAC",
                outputExtension: "aac",
                requiredEncoderKey: "aac",
                requiredMuxerKey: "adts",
                ffmpegArgs: ["-vn", "-c:a", "aac", "-b:a", "192k", "-f", "adts"]
            ),
            SupportedFormat(
                id: "wav",
                displayName: "WAV",
                outputExtension: "wav",
                requiredEncoderKey: "pcm_s16le",
                requiredMuxerKey: "wav",
                ffmpegArgs: ["-vn", "-c:a", "pcm_s16le"]
            ),
            SupportedFormat(
                id: "flac",
                displayName: "FLAC",
                outputExtension: "flac",
                requiredEncoderKey: "flac",
                requiredMuxerKey: "flac",
                ffmpegArgs: ["-vn", "-c:a", "flac"]
            ),
            SupportedFormat(
                id: "aiff",
                displayName: "AIFF",
                outputExtension: "aiff",
                requiredEncoderKey: "pcm_s16be",
                requiredMuxerKey: "aiff",
                ffmpegArgs: ["-vn", "-c:a", "pcm_s16be"]
            ),
            SupportedFormat(
                id: "opus",
                displayName: "Opus",
                outputExtension: "opus",
                requiredEncoderKey: "libopus",
                requiredMuxerKey: "opus",
                ffmpegArgs: ["-vn", "-c:a", "libopus", "-b:a", "160k"]
            ),
            SupportedFormat(
                id: "ogg",
                displayName: "Ogg Vorbis",
                outputExtension: "ogg",
                requiredEncoderKey: "libvorbis",
                requiredMuxerKey: "ogg",
                ffmpegArgs: ["-vn", "-c:a", "libvorbis", "-q:a", "5"]
            )
        ]

        return Dictionary(uniqueKeysWithValues: formats.map { ($0.id, $0) })
    }()

    static var allFormats: [SupportedFormat] {
        formatsByKey.values.sorted { $0.displayName < $1.displayName }
    }

    static func normalizedKey(for input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
    }

    static func format(for input: String) -> SupportedFormat? {
        formatsByKey[normalizedKey(for: input)]
    }

    static var requiredEncoderKeys: Set<String> {
        Set(allFormats.map { $0.requiredEncoderKey.lowercased() })
    }

    static var requiredMuxerKeys: Set<String> {
        Set(allFormats.map { $0.requiredMuxerKey.lowercased() })
    }
}
