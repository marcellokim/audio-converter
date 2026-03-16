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

    func start(ffmpegURL: URL, arguments: [String]) throws -> FFmpegTaskRunning {
        capturedURL = ffmpegURL
        capturedArguments = arguments

        if let error {
            throw error
        }

        return ImmediateSpyFFmpegTask(result: .success(result))
    }
}

private final class ImmediateSpyFFmpegTask: FFmpegTaskRunning {
    private let result: Result<FFmpegRunResult, Error>

    init(result: Result<FFmpegRunResult, Error>) {
        self.result = result
    }

    func wait() throws -> FFmpegRunResult {
        try result.get()
    }

    func cancel() {}

    func setProgressHandler(_ handler: @escaping (FFmpegProgressEvent) -> Void) {}
}
