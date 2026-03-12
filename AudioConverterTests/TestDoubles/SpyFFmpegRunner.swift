import Foundation
@testable import AudioConverter

final class SpyFFmpegRunner: FFmpegRunning {
    var result = FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: "")
    var error: Error?
    var capturedArguments: [String] = []
    var capturedURL: URL?

    func run(ffmpegURL: URL, arguments: [String]) throws -> FFmpegRunResult {
        capturedURL = ffmpegURL
        capturedArguments = arguments

        if let error {
            throw error
        }

        return result
    }
}
