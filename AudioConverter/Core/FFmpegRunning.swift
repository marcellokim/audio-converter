import Foundation

struct FFmpegRunResult: Equatable {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String
    let wasCancelled: Bool

    init(
        terminationStatus: Int32,
        standardOutput: String,
        standardError: String,
        wasCancelled: Bool = false
    ) {
        self.terminationStatus = terminationStatus
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.wasCancelled = wasCancelled
    }
}

struct FFmpegProgressEvent: Equatable {
    let outTimeSeconds: Double?
    let progressState: String
}

protocol FFmpegTaskRunning {
    func wait() throws -> FFmpegRunResult
    func cancel()
    func setProgressHandler(_ handler: @escaping (FFmpegProgressEvent) -> Void)
}

protocol FFmpegRunning {
    func start(ffmpegURL: URL, arguments: [String]) throws -> FFmpegTaskRunning
    func run(ffmpegURL: URL, arguments: [String]) throws -> FFmpegRunResult
}

extension FFmpegRunning {
    func start(ffmpegURL: URL, arguments: [String]) throws -> FFmpegTaskRunning {
        let result = Result { try run(ffmpegURL: ffmpegURL, arguments: arguments) }
        return ImmediateFFmpegTask(result: result)
    }

    func run(ffmpegURL: URL, arguments: [String]) throws -> FFmpegRunResult {
        try start(ffmpegURL: ffmpegURL, arguments: arguments).wait()
    }
}

private struct ImmediateFFmpegTask: FFmpegTaskRunning {
    let result: Result<FFmpegRunResult, Error>

    func wait() throws -> FFmpegRunResult {
        try result.get()
    }

    func cancel() {}

    func setProgressHandler(_ handler: @escaping (FFmpegProgressEvent) -> Void) {}
}
