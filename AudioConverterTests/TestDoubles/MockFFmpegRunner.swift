import Foundation
@testable import AudioConverter

final class MockFFmpegRunner: FFmpegRunning {
    enum RunnerError: Error {
        case launchFailed
    }

    var results: [Result<FFmpegRunResult, Error>] = []
    private(set) var invocations: [(ffmpegURL: URL, arguments: [String])] = []

    func run(ffmpegURL: URL, arguments: [String]) throws -> FFmpegRunResult {
        invocations.append((ffmpegURL, arguments))
        guard !results.isEmpty else {
            return FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: "")
        }

        let next = results.removeFirst()
        switch next {
        case let .success(result):
            return result
        case let .failure(error):
            throw error
        }
    }
}
