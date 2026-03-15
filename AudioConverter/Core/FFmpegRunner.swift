import Foundation

struct FFmpegRunner: FFmpegRunning {
    func start(ffmpegURL: URL, arguments: [String]) throws -> FFmpegTaskRunning {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = ffmpegURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let task = ProcessBackedFFmpegTask(
            process: process,
            outputPipe: outputPipe,
            errorPipe: errorPipe
        )

        try process.run()
        return task
    }
}

private final class ProcessBackedFFmpegTask: FFmpegTaskRunning {
    private let process: Process
    private let outputPipe: Pipe
    private let errorPipe: Pipe
    private let lock = NSLock()

    private var cancellationRequested = false

    init(process: Process, outputPipe: Pipe, errorPipe: Pipe) {
        self.process = process
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
    }

    func wait() throws -> FFmpegRunResult {
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        lock.lock()
        let wasCancelled = cancellationRequested
        lock.unlock()

        return FFmpegRunResult(
            terminationStatus: process.terminationStatus,
            standardOutput: output,
            standardError: error,
            wasCancelled: wasCancelled
        )
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let shouldTerminate = process.isRunning
        lock.unlock()

        guard shouldTerminate else {
            return
        }

        process.terminate()
    }
}
