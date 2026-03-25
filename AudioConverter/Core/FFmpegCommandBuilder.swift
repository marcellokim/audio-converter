import Foundation

enum FFmpegCommandBuilder {
    private static let safetyFlags = [
        "-hide_banner",
        "-loglevel", "error",
        "-nostdin",
        "-nostats",
        "-progress", "pipe:1",
        "-n"
    ]

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

    static func makeMergeCommand(
        ffmpegURL: URL,
        inputURLs: [URL],
        outputURL: URL,
        outputFormat: SupportedFormat
    ) -> [String] {
        [ffmpegURL.path] + makeMergeArguments(
            inputURLs: inputURLs,
            outputURL: outputURL,
            outputFormat: outputFormat
        )
    }

    static func makeMergeArguments(
        inputURLs: [URL],
        outputURL: URL,
        outputFormat: SupportedFormat
    ) -> [String] {
        let inputArguments = inputURLs.flatMap { ["-i", $0.path] }
        return safetyFlags
            + inputArguments
            + ["-filter_complex", makeMergeFilterGraph(inputCount: inputURLs.count)]
            + ["-map", "[merged]", "-ac", "2", "-ar", "44100"]
            + outputFormat.ffmpegArgs
            + [outputURL.path]
    }

    static func makeMergeFilterGraph(inputCount: Int) -> String {
        precondition(inputCount > 1, "Ordered merge requires at least two inputs.")

        let normalizedInputs = (0..<inputCount).map { index in
            "[\(index):a:0]aresample=async=1:first_pts=0,aformat=sample_rates=44100:sample_fmts=fltp:channel_layouts=stereo[a\(index)]"
        }

        let concatInputs = (0..<inputCount).map { "[a\($0)]" }.joined()
        return (normalizedInputs + ["\(concatInputs)concat=n=\(inputCount):v=0:a=1[merged]"]).joined(separator: ";")
    }
}
