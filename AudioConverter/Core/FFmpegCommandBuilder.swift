import Foundation

enum FFmpegCommandBuilder {
    private static let safetyFlags = ["-hide_banner", "-loglevel", "error", "-nostdin", "-n"]

    static func makeCommand(
        ffmpegURL: URL,
        inputURL: URL,
        outputURL: URL,
        outputFormat: SupportedFormat
    ) -> [String] {
        [ffmpegURL.path] + safetyFlags + ["-i", inputURL.path] + outputFormat.ffmpegArgs + [outputURL.path]
    }

    static func makeArguments(
        inputURL: URL,
        outputURL: URL,
        outputFormat: SupportedFormat
    ) -> [String] {
        safetyFlags + ["-i", inputURL.path] + outputFormat.ffmpegArgs + [outputURL.path]
    }
}
